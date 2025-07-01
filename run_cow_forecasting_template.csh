#!/bin/csh
#SBATCH --output="wrfoa-%j"
#SBATCH --job-name=cow-frc
#SBATCH --partition=mpi_long2
#SBATCH --nodes=2
#SBATCH --ntasks=48

########################################################
#  Define environment variables for XEON
########################################################
#setenv OMP_SCHEDULE static
#setenv OMP_NUM_THREADS 8
#setenv OMP_DYNAMIC false
#setenv OMP_NESTED false
#setenv KMP_LIBRARY throughput
#setenv KMP_STACKSIZE 16m
#setenv KMP_DUPLICATE_LIB_OK TRUE
#
#
########################################################
#    Define PATH FOR CALMIP
########################################################
#source ${MODULESHOME}/init/csh
##module load intel/11.0.083
##module load intel_ompi/1.4.2
#
set NB_PROC_MPI_ROMS=8
set NB_PROC_MPI_WRF=40
########################################################
echo " "
echo "ROMS-OASIS-WRF running --- MODULO5 running "
echo " "
#
# Frequency of model runs, if NSLICE==0 is remains monthly
set NSLICE=0 
#
# Alias
unalias cp
unalias mv
set CP=/bin/cp
set MV=/bin/mv
set LN=/bin/ln 
#
########################################################
#  Define files and run parameters
########################################################
#
# Work Directory
#set SCRATCHDIR=/data/datos/COW/cow_v1/pronostico/CFS/cow/outputs_04
set SCRATCHDIR=$cow_link_member
#
# Executables
set ROMS_INPUTDIR=/data/users/cow/CROCO-OA-WRF4/croco-v2.0.0/Run-gnu12-oa3v5_fecg
set WRF_INPUTDIR=/data/users/cow/CROCO-OA-WRF4/WRF-gnu12-oa3v5/run
set ROMS_CODFILE=croco
set WRF_CODFILE=wrf.exe
#
# ROMS Input files
set ROMS_MODEL=croco
#set ROMS_MSSDIR=/data/datos/COW/cow_v1/pronostico/CFS/ocean/2024050100/without_corr/croco_files
set ROMS_MSSDIR=$roms_link_member
#set AGRIF_FILE=AGRIF_FixedGrids.in
#
# WRF Input files
set WRF_MODEL=wrf
#set WRF_MSSDIR=/data/datos/COW/cow_v1/pronostico/CFS/atmosphere/wrf_files_without_corr
set WRF_MSSDIR=$wrf_link_member
#
# OASIS Input files
set OASIS_MSSDIR=/data/users/cow/CROCO-OA-WRF4/OASIS/Run-gnu12-oa3v5-crocov2/oasis_files
#set OASIS_RSTFILE = sstoc
#
# Commande specifiques a IntelMPI
#
#$CP -f mpd.hosts ${SCRATCHDIR}
#$CP -f nodes ${SCRATCHDIR}
#
#
set BULK_FILES=0
set FORCING_FILES=0
set CLIMATOLOGY_FILES=0
set BOUNDARY_FILES=1
#
# Atmospheric surface forcing dataset used for the bulk formula (NCEP)
#
set ATMOS_BULK=XXXXX
#
# Atmospheric surface forcing dataset used for the wind stress (NCEP, QSCAT)
#
set ATMOS_FRC=XXXXX
#
# Oceanic boundary and initial dataset (SODA, ECCO,...)
#
set OGCM=cfs
#
# Model time step [seconds]
#
set DT_ROMS=900
set DT_WRF=90
@ DIFF_DT = $DT_ROMS - $DT_WRF
#
# number total of grid levels (1: No child grid)
#
set NLEVEL=1
#
set NY_START=`date +%Y`
set NM_START=`date +%-m`
set ND_START=1
#
#set NY_END=`date -d "+3 month" +%Y`
#set NM_END=`date -d "+3 month" +%-m`
set NY_END=`date -d "+6 month" +%Y`
set NM_END=`date -d "+6 month" +%-m`
set ND_END=`date -d "$NY_END-$((10#$NM_END + 1))-01 - 1 day" +%d`

#
set NY_SPIN=0
@ NY_BEG = $NY_START + $NY_SPIN
#
#  Restart file - RSTFLAG=0 --> No Restart
#		  RSTFLAG=1 --> Restart
#
set RSTFLAG=1
#
#  Time Schedule  -  TIME_SCHED=0 --> yearly files
#                    TIME_SCHED=1 --> monthly files
#
set TIME_SCHED=1
#
########################################################
#
if ($TIME_SCHED == 0) then
  set NM_START=1992
  set NM_END=1992
endif
#
# ROMS netcdf file prefixes
#
set GRDFILE=${ROMS_MODEL}_grd
set FRCFILE=${ROMS_MODEL}_frc
set BLKFILE=${ROMS_MODEL}_blk
set INIFILE=${ROMS_MODEL}_ini
set CLMFILE=${ROMS_MODEL}_clm
set BRYFILE=${ROMS_MODEL}_bry
#
# WRF netcdf file prefixes
set WRF_INPUT=${WRF_MODEL}input_d01
set WRF_LOWINP=${WRF_MODEL}lowinp_d01
set WRF_BDY=${WRF_MODEL}bdy_d01
set WRF_FDDA=${WRF_MODEL}fdda_d01
#
#
if ($RSTFLAG != 0) then
        set NY=$NY_START
        set NM=$NM_START
	if ($NSLICE == 0) then
	    set NY=$NY_START
	    set NM=$NM_START
	    if ($TIME_SCHED == 0) then
		@ NY--
		set TIME=Y${NY}
                set WRF_TIME=${NY}
	    else
		@ NM--
		if ($NM == 0) then
		    set NM=12
		    @ NY--
		endif
	        set TIME=Y${NY}M${NM}
	        set WRF_TIME=${NY}${NM}
                if (${NM} < 10 ) then
                     set TIME=Y${NY}M0${NM}
                     set WRF_TIME=${NY}0${NM}
                endif
            endif
       else #if ($NSLICE ~= 0) 
	    @ day_mid = $ND_START + $NSLICE / 2
	    @ day_mid = $day_mid - $NSLICE

             if ($day_mid < 1) then
	     	@ NM--
		if ($NM == 0) then
		    set NM=12
		    @ NY--
		endif

		if (${NM} == 1 || ${NM} == 3 || ${NM} == 5 || ${NM} == 7 || ${NM} == 8 || ${NM} == 10 || ${NM} == 12 ) then
		    set NDAYS = 31
		else
		    set NDAYS = 30
		    if (${NM} == 2) then
			set NDAYS = 28
			set B2=0
			set B100=0
			set B400=0
			@ B4 = 4 * ( $NY / 4 )
			@ B100 = 100 * ( $NY / 100 )
			@ B400 = 400 * ( $NY / 400 )
			if (($NY >= $NY_BEG) & ($NY == $B4 & ((!($NY == $B100))||($NY == $B400)))) then
				echo Leap Year
				set NDAYS = 29		  
			endif
		    endif
		endif
	        @ day_mid = $day_mid + $NDAYS
             endif

	     set TIME=Y${NY}M${NM}D${day_mid}
	     set WRF_TIME=${NY}${NM}${day_mid}
	     if (${NM} < 10 ) then
		     if  ( ${day_mid} < 10 ) then
			set TIME=Y${NY}M0${NM}D0${day_mid}
			set WRF_TIME=${NY}0${NM}0${day_mid}
		     else
			set TIME=Y${NY}M0${NM}D${day_mid}
			set WRF_TIME=${NY}0${NM}${day_mid}
		     endif
	      else
		    if  ( ${day_mid} < 10 ) then
			set TIME=Y${NY}M${NM}D0${day_mid}
			set WRF_TIME=${NY}${NM}0${day_mid}
		    else
			set TIME=Y${NY}M${NM}D${day_mid}
			set WRF_TIME=${NY}${NM}${day_mid}
                    endif
	      endif
         endif	          
set ROMS_RSTFILE=${ROMS_MODEL}_rst_${TIME}
if (${NM_START} < 10 ) then
   if ( ${ND_START} < 10 ) then
      set WRF_RSTFILE=${WRF_MODEL}rst_d01_${NY_START}-0${NM_START}-0${ND_START}_00:00:00
    else
      set WRF_RSTFILE=${WRF_MODEL}rst_d01_${NY_START}-0${NM_START}-${ND_START}_00:00:00
    endif
else
   if ( ${ND_START} < 10 ) then
      set WRF_RSTFILE=${WRF_MODEL}rst_d01_${NY_START}-${NM_START}-0${ND_START}_00:00:00
    else
      set WRF_RSTFILE=${WRF_MODEL}rst_d01_${NY_START}-${NM_START}-${ND_START}_00:00:00
    endif
endif
endif
#
#set OASIS_RSTFILE_TIME = ${OASIS_RSTFILE}_${TIME}
#
if ($TIME_SCHED == 0) then
  set TIME=Y${NY_START}
else
  set TIME=Y${NY_START}M${NM_START}
endif
#
# Get the codes
#
cd $SCRATCHDIR
echo "Getting $ROMS_CODFILE from $ROMS_INPUTDIR"
$CP -f $ROMS_INPUTDIR/$ROMS_CODFILE $SCRATCHDIR/crocox
set ROMS_CODFILE = crocox
chmod u+x $ROMS_CODFILE
echo "Getting $WRF_CODFILE from $WRF_INPUTDIR"
$CP -f $WRF_INPUTDIR/$WRF_CODFILE $SCRATCHDIR/wrfexe
set WRF_CODFILE = wrfexe
chmod u+x $WRF_CODFILE
#$CP -f ../SCRIPTS/script_make_restart_sstoc.scr $SCRATCHDIR
#
# Get WRF files
echo "Getting WRF files from $WRF_MSSDIR/inputs_files"
$CP -f $WRF_MSSDIR/inputs_files/* $SCRATCHDIR
echo "Getting WRF namelist.input from $WRF_MSSDIR"
$CP -f $WRF_MSSDIR/namelist.input-generic $SCRATCHDIR
$CP -f $WRF_MSSDIR/iofields_file.txt $SCRATCHDIR
#
# Get OASIS files
echo "Getting OASIS files from $OASIS_MSSDIR"
$CP -f $OASIS_MSSDIR/*.nc $SCRATCHDIR
#
#
#echo "Getting $AGRIF_FILE from $ROMS_INPUTDIR"
#$CP -f $ROMS_INPUTDIR/$AGRIF_FILE $SCRATCHDIR
#
# Get the netcdf files
#
set LEVEL=0
while ($LEVEL != $NLEVEL)
  if (${LEVEL} == 0) then
    set ENDF=
  else
    set ENDF=.${LEVEL}
  endif
  echo "Getting ${GRDFILE}.nc${ENDF} from $ROMS_MSSDIR"
  $LN -sf $ROMS_MSSDIR/${GRDFILE}.nc${ENDF} $SCRATCHDIR
  echo "Getting ${ROMS_MODEL}_inter.in${ENDF} from $ROMS_INPUTDIR"
  $CP -f $ROMS_MSSDIR/${ROMS_MODEL}_inter.in${ENDF} $SCRATCHDIR
  if ($NY_SPIN > 0) then
     $CP -f $ROMS_MSSDIR/${ROMS_MODEL}_inter_spin.in${ENDF} $SCRATCHDIR
  endif
  if ($RSTFLAG == 0) then
    echo "Getting ${INIFILE}_${OGCM}_${TIME}.nc${ENDF} from $ROMS_MSSDIR"
    $LN -sf $ROMS_MSSDIR/${INIFILE}_${OGCM}_${TIME}.nc${ENDF} $SCRATCHDIR
    $LN -sf ${INIFILE}_${OGCM}_${TIME}.nc${ENDF} ${INIFILE}.nc${ENDF}
  else
    if( ! -e ${ROMS_RSTFILE}.nc${ENDF} ) then 
       echo "Getting ${ROMS_RSTFILE}.nc${ENDF} from $ROMS_MSSDIR"
       $LN -sf $ROMS_MSSDIR/${ROMS_RSTFILE}.nc${ENDF} ${INIFILE}.nc${ENDF}
    else 
       echo "Getting ${ROMS_RSTFILE}.nc${ENDF} from $SCRATCHDIR"
       $LN -sf ${ROMS_RSTFILE}.nc${ENDF} ${INIFILE}.nc${ENDF}
    endif
    if( ! -e ${WRF_RSTFILE} ) then
       echo "Getting ${WRF_RSTFILE} from $WRF_MSSDIR"
       $LN -sf $WRF_MSSDIR/${WRF_RSTFILE} ${WRF_RSTFILE}
    endif
  endif
  @ LEVEL++
end

#if( ! -e ${OASIS_RSTFILE_TIME}.nc ) then 
#  if( ! -e ${OASIS_MSSDIR}/${OASIS_RSTFILE_TIME}.nc ) then  
#     echo "Creating ${OASIS_RSTFILE}.nc using ${INIFILE}.nc"
#     ./script_make_restart_sstoc.scr ${INIFILE}.nc    
#  else
#     echo "Getting ${OASIS_RSTFILE_TIME}_.nc from ${OASIS_MSSDIR}"
#     $CP -f ${OASIS_MSSDIR}/${OASIS_RSTFILE_TIME}.nc ${OASIS_RSTFILE}.nc 
#  endif
#else
#  echo "Getting ${OASIS_RSTFILE_TIME}.nc from ${SCRATCHDIR}"
#  $CP -f ${OASIS_RSTFILE_TIME}.nc ${OASIS_RSTFILE}.nc
#endif


echo " "
#
###########################################################
#  Compute
###########################################################
#
set NY=$NY_START
set NM=$NM_START

@ day_beg = $ND_START
@ day_mid = $ND_START + $NSLICE / 2

if (${NM} == 1 || ${NM} == 3 || ${NM} == 5 || ${NM} == 7 || ${NM} == 8 || ${NM} == 10 || ${NM} == 12 ) then
    set NDAYS = 31
else
     set NDAYS = 30
     if (${NM} == 2) then
	  set NDAYS = 28
	  set B2=0
	  set B100=0
	  set B400=0
	  @ B4 = 4 * ( $NY / 4 )
	  @ B100 = 100 * ( $NY / 100 )
	  @ B400 = 400 * ( $NY / 400 )
	   if (($NY >= $NY_BEG) & ($NY == $B4 & ((!($NY == $B100))||($NY == $B400)))) then
		 echo Leap Year
		 set NDAYS = 29		  
	   endif
      endif
endif

if ($day_mid > $NDAYS) then
        @ day_beg = $day_beg - $NDAYS
	@ day_mid = $day_mid - $NDAYS
	@ NM++
	if ($NM > 12 ) then
            set NM = 1
	    @ NY++
	endif
endif
@ day_end = $day_beg + $NSLICE - 1	

set it_is_not_finished = 1
set it_is_not_planted = 1

while ($it_is_not_finished == 1) #while ($NY != $NY_END)

    if ($NSLICE == 0) then
        if ($TIME_SCHED == 0) then
          set TIME=Y${NY}
          set WRF_TIME=${NY}
          echo "Computing YEAR $NY"
        else
          set TIME=Y${NY}M${NM}
          set WRF_TIME=${NY}${NM}         
          if (${NM} < 10 ) then
              set TIMEnew=Y${NY}M0${NM}
              set WRF_TIMEnew=${NY}0${NM}
          else
              set TIMEnew=Y${NY}M${NM}
              set WRF_TIMEnew=${NY}${NM}
          endif
          echo "Computing YEAR $NY MONTH $NM"
        endif
        echo "Computing YEAR $NY MONTH $NM"
    else
        set TIME=Y${NY}M${NM}
        set WRF_TIME=${NY}${NM}
        set WRF_TIMEnew=${NY}${NM}        
        set TIMEmid=Y${NY}M${NM}D${day_mid}
        set WRF_TIMEmid=${NY}${NM}${day_mid}
        if (${NM} < 10 ) then
            set WRF_TIMEnew=${NY}0${NM}
            if  ( ${day_mid} < 10 ) then
                set TIMEmid=Y${NY}M0${NM}D0${day_mid}
                set WRF_TIMEmid=${NY}0${NM}0${day_mid}
            else
                set TIMEmid=Y${NY}M0${NM}D${day_mid}
                set WRF_TIMEmid=${NY}0${NM}${day_mid}
            endif
         else
             set WRF_TIMEnew=${NY}${NM}
             if  ( ${day_mid} < 10 ) then
                 set TIMEmid=Y${NY}M${NM}D0${day_mid}
                 set WRF_TIMEmid=${NY}${NM}0${day_mid}
             else
                 set TIMEmid=Y${NY}M${NM}D${day_mid}
                 set WRF_TIMEmid=${NY}${NM}${day_mid}
             endif
         endif
        echo "Computing YEAR $NY MONTH $NM from day $day_beg to $day_end, mid_day is $day_mid"
    endif
#
# Get forcing and clim for this time
#
    set LEVEL=0
    while ($LEVEL != $NLEVEL)
      if (${LEVEL} == 0) then
        set ENDF=
      else
        set ENDF=.${LEVEL}
      endif
      if (${FORCING_FILES} == 1) then
        echo "-- > Getting ${FRCFILE}_${ATMOS_FRC}_${TIME}.nc${ENDF} from $ROMS_MSSDIR"
        $LN -sf $ROMS_MSSDIR/${FRCFILE}_${ATMOS_FRC}_${TIME}.nc${ENDF} ${FRCFILE}.nc${ENDF}
      endif
      if (${BULK_FILES} == 1) then
        echo "-- > Getting ${BLKFILE}_${ATMOS_BULK}_${TIME}.nc${ENDF} from $ROMS_MSSDIR"
        $LN -sf $ROMS_MSSDIR/${BLKFILE}_${ATMOS_BULK}_${TIME}.nc${ENDF} ${BLKFILE}.nc${ENDF}
      endif
      @ LEVEL++
    end
#
# No child climatology or boundary files
#
    if (${CLIMATOLOGY_FILES} == 1) then
      echo "-- > Getting ${CLMFILE}_${OGCM}_${TIME}.nc from $ROMS_MSSDIR"
      $LN -sf $ROMS_MSSDIR/${CLMFILE}_${OGCM}_${TIME}.nc ${CLMFILE}.nc
    endif
    if (${BOUNDARY_FILES} == 1) then
      echo "-- > Getting ${BRYFILE}_${OGCM}_${TIME}.nc from $ROMS_MSSDIR"
      $LN -sf $ROMS_MSSDIR/${BRYFILE}_${OGCM}_${TIME}.nc ${BRYFILE}.nc
#      $LN -sf $ROMS_MSSDIR/PERU7_5dSODA_96_05_bry.nc ${BRYFILE}.nc

    endif
# 
# Get WRF BDY files
    echo "-- > Getting ${WRF_BDY}_${WRF_TIMEnew} from $WRF_MSSDIR"
    $LN -sf $WRF_MSSDIR/${WRF_BDY}_${WRF_TIMEnew} ${WRF_BDY} 
# 
# Get WRF LOWINP files
    echo "-- > Getting ${WRF_LOWINP}_${WRF_TIMEnew} from $WRF_MSSDIR"
    $LN -sf $WRF_MSSDIR/${WRF_LOWINP}_${WRF_TIMEnew} ${WRF_LOWINP} 
#
# Get WRF INPUT files
    echo "-- > Getting ${WRF_INPUT}_${WRF_TIMEnew} from $WRF_MSSDIR"
    $LN -sf $WRF_MSSDIR/${WRF_INPUT}_${WRF_TIMEnew} ${WRF_INPUT}  
#    $LN -sf $WRF_MSSDIR/CPLMASK.nc CPLMASK.nc
#   ncks -A $WRF_MSSDIR/CPLMASK.nc ${WRF_INPUT}
#   ncap2 -O -s "CPLMASK(:,0,:,:)=(LANDMASK-1)*(-1)" $WRF_MSSDIR/${WRF_INPUT}_${WRF_TIMEnew} $WRF_MSSDIR/${WRF_INPUT}_${WRF_TIMEnew}
   ncap2 -O -s "CPLMASK(:,0,:,:)=(LANDMASK-1)*(-1)" ${WRF_INPUT} ${WRF_INPUT}

#
# Get WRF FDDA files
    echo "-- > Getting ${WRF_FDDA}_${WRF_TIMEnew} from $WRF_MSSDIR"
    $LN -sf $WRF_MSSDIR/${WRF_FDDA}_${WRF_TIMEnew} ${WRF_FDDA}
#
# Set the number of time steps for each month 
# (30 or 31 days + 28 or 29 days for february)
#
    set NUMTIMES=0
#
    if (${NM} == 1 || ${NM} == 3 || ${NM} == 5 || ${NM} == 7 || ${NM} == 8 || ${NM} == 10 || ${NM} == 12 ) then
      set NDAYS = 31
    else
      set NDAYS = 30
      if (${NM} == 2) then
        set NDAYS = 28
# February... check if it is a leap year
        set B2=0
        set B100=0
        set B400=0
        @ B4 = 4 * ( $NY / 4 )
        @ B100 = 100 * ( $NY / 100 )
        @ B400 = 400 * ( $NY / 400 )
        if (($NY >= $NY_BEG) & ($NY == $B4 & ((!($NY == $B100))||($NY == $B400)))) then
	  echo Leap Year
          set NDAYS = 29		  
        endif
      endif
    endif

    if ($NSLICE == 0) then
        @ NUMTIMES = $NDAYS * 24 * 3600
        @ NUMTIMES = $NUMTIMES / $DT_ROMS
        echo "-- > YEAR = $NY MONTH = $NM DAYS = $NDAYS DT_ROMS = $DT_ROMS NTIMES = $NUMTIMES"
    else
        @ NUMTIMES = $NSLICE * 24 * 3600
        @ NUMTIMES = $NUMTIMES / $DT_ROMS
        echo "-- > YEAR = $NY MONTH = $NM DAYS = $NDAYS DT_ROMS = $DT_ROMS NTIMES = $NUMTIMES"
    endif
    @ NUMSECS = $NUMTIMES * $DT_ROMS
    @ NUMMINS = $NUMSECS / 60
# 
    set LEVEL=0
    while ($LEVEL != $NLEVEL)
      if (${LEVEL} == 0) then
        set ENDF=
      else
        set ENDF=.${LEVEL}
	@ NUMTIMES = 3 * $NUMTIMES
      endif
      if ($NSLICE == 0) then
          if ($NY >= $NY_BEG) then
             echo "-- > Using ${ROMS_MODEL}_${TIME}_inter.in, with NUMTINES=$NUMTIMES"
             sed -e 's/NUMTIMES/'$NUMTIMES'/' \
                 -e 's/DT_ROMS/'$DT_ROMS'/' ${ROMS_MODEL}_inter.in${ENDF} > ${ROMS_MODEL}_${TIME}_inter.in${ENDF}
             $CP ${ROMS_MODEL}_${TIME}_inter.in${ENDF} croco.in
          else
              echo "-- > Using ${ROMS_MODEL}_${TIME}_inter_spin.in, with NUMTINES=$NUMTIMES"
              sed -e 's/NUMTIMES/'$NUMTIMES'/' \
                 -e 's/DT_ROMS/'$DT_ROMS'/' ${ROMS_MODEL}_inter_spin.in${ENDF} > ${ROMS_MODEL}_${TIME}_inter.in${ENDF}
              $CP ${ROMS_MODEL}_${TIME}_inter.in${ENDF} croco.in
          endif	
      else  
          echo "-- > Using ${ROMS_MODEL}_${TIMEmid}_inter.in, with NUMTINES=$NUMTIMES"
          sed -e 's/NUMTIMES/'$NUMTIMES'/' \
              -e 's/DT_ROMS/'$DT_ROMS'/' ${ROMS_MODEL}_inter.in${ENDF} > ${ROMS_MODEL}_${TIMEmid}_inter.in${ENDF}
          $CP ${ROMS_MODEL}_${TIMEmid}_inter.in${ENDF} croco.in
      endif
      @ LEVEL++
    end
#
# Handling WRF namelist.input file
#
    if ($NSLICE == 0) then
      set YBEG = $NY
      set MBEG = $NM
      set DBEG = '01'
      set DEND = '01'
      set YEND = $YBEG
      @ MEND = $MBEG + 1
      if ($MEND > 12 ) then
        set MEND = 1
        @ YEND = $YBEG + 1
      endif
      if (${MBEG} < 10 ) then
         set MBEG = 0${MBEG}
      endif
      if (${MEND} < 10 ) then
         set MEND = 0${MEND}
      endif
    else
      set YBEG = $NY
      set MBEG = $NM     
      @ DBEG = $day_mid - $NSLICE / 2

      if ($DBEG < 1) then
 	@ MBEG-- 
        if ($MBEG == 0) then
           set MBEG=12
           @ YBEG--
        endif
        if (${MBEG} == 1 || ${MBEG} == 3 || ${MBEG} == 5 || ${MBEG} == 7 || ${MBEG} == 8 || ${MBEG} == 10 || ${MBEG} == 12 ) then
           set NDAYSM = 31
        else
           set NDAYSM = 30
           if (${MBEG} == 2) then
	     set NDAYSM = 28
	     set B2=0
	     set B100=0
	     set B400=0
	     @ B4 = 4 * ( $YBEG / 4 )
	     @ B100 = 100 * ( $YBEG / 100 )
	     @ B400 = 400 * ( $YBEG / 400 )
	     if (($YBEG >= $NY_BEG) & ($YBEG == $B4 & ((!($YBEG == $B100))||($YBEG == $B400)))) then
		 set NDAYSM= 29		  
	     endif
           endif
        endif
        @ DBEG = $NDAYSM +  $DBEG 
      endif 

      set YEND = $YBEG
      set MEND = $MBEG
        if (${MEND} == 1 || ${MEND} == 3 || ${MEND} == 5 || ${MEND} == 7 || ${MEND} == 8 || ${MEND} == 10 || ${MEND} == 12 ) then
           set NDAYSM = 31
        else
           set NDAYSM = 30
           if (${MEND} == 2) then
	     set NDAYSM = 28
	     set B2=0
	     set B100=0
	     set B400=0
	     @ B4 = 4 * ( $YEND / 4 )
	     @ B100 = 100 * ( $YEND / 100 )
	     @ B400 = 400 * ( $YEND / 400 )
	     if (($YEND >= $NY_END) & ($YEND == $B4 & ((!($YEND == $B100))||($YEND == $B400)))) then
		 set NDAYSM= 29		  
	     endif
           endif
        endif
      @ DEND = $DBEG + $NSLICE 
      if ($DEND > $NDAYSM) then
	@ MEND = $MBEG + 1
	if ($MEND > 12 ) then
            set MEND = 1
	    @ YEND++
	endif
	@ DEND = $DEND - $NDAYSM
      endif

      if (${MBEG} < 10 ) then
         set MBEG = 0${MBEG}
      endif
      if (${MEND} < 10 ) then
         set MEND = 0${MEND}
      endif
      if (${DBEG} < 10 ) then
         set DBEG = 0${DBEG}
      endif
      if (${DEND} < 10 ) then
         set DEND = 0${DEND}
      endif      
    endif
    if ($NSLICE == 0) then
       echo "-- > Using namelist.input, with NDAYS=$NDAYS"
       sed -e 's/NDAYS/'$NDAYS'/g' \
           -e 's/YBEG/'$YBEG'/g' \
           -e 's/MBEG/'$MBEG'/g'  \
           -e 's/DBEG/'$DBEG'/g'  \
           -e 's/YEND/'$YEND'/g' \
           -e 's/MEND/'$MEND'/g'  \
           -e 's/DEND/'$DEND'/g'  \
           -e 's/WRF_RST_TIME/'$NUMMINS'/g'  namelist.input-generic > namelist.input
           $CP -f namelist.input namelist.input_${TIME}
    else
       echo "-- > Using namelist.input, with NDAYS=$NSLICE"
       sed -e 's/NDAYS/'$NSLICE'/g' \
           -e 's/YBEG/'$YBEG'/g' \
           -e 's/MBEG/'$MBEG'/g'  \
           -e 's/DBEG/'$DBEG'/g'  \
           -e 's/YEND/'$YEND'/g' \
           -e 's/MEND/'$MEND'/g'  \
           -e 's/DEND/'$DEND'/g'  \
           -e 's/WRF_RST_TIME/'$NUMMINS'/g'  namelist.input-generic > namelist.input
       $CP -f namelist.input namelist.input_${TIMEmid}
    endif
#
# Handling OASIS-MCT namcouple file
#
    echo "-- > Getting OASIS namcouple from $OASIS_MSSDIR"
#    if (${NM} < 4 ) then    
#       $CP -f $OASIS_MSSDIR/namcouple-mct-generic5 $SCRATCHDIR/namcouple-mct-generic
#    else
       $CP -f $OASIS_MSSDIR/namcouple-mct-generic6 $SCRATCHDIR/namcouple-mct-generic
#    endif
    if ($NSLICE == 0) then
       set INIDATE = ${NY}${NM}
       if (${NM} < 10 ) then
          set INIDATE = ${NY}0${NM}
       endif
    else
       set INIDATE = ${YBEG}${MBEG}${DBEG}
    endif
    echo "-- > Using namcouple, with NUMSECS=$NUMSECS"
    sed -e 's/NUMSECS/'$NUMSECS'/g' \
        -e 's/NB_PROC_MPI_ROMS/'$NB_PROC_MPI_ROMS'/g' \
        -e 's/NB_PROC_MPI_WRF/'$NB_PROC_MPI_WRF'/g'  \
        -e 's/DT_ROMS/'$DT_ROMS'/g'  \
        -e 's/DIFF_DT/'$DIFF_DT'/g'  \
        -e 's/WRF_CODFILE/'$WRF_CODFILE'/g'  \
        -e 's/ROMS_CODFILE/'$ROMS_CODFILE'/g'  \
        -e 's/OASIS_INIDATE/'$INIDATE'/g'  namcouple-mct-generic > namcouple
    if ($NSLICE == 0) then
       $CP -f namcouple namcouple_${TIME}
    else
       $CP -f namcouple namcouple_${TIMEmid}
    endif

#
#  COMPUTE
#
    echo "-- > *** RUNNING *** @" `date`
    if ($NSLICE == 0) then
        #echo "Monthly: Check files and enter a key"
        #set JUNKKEY = $<
        #mpiexec -machinefile nodes -np ${NB_PROC_MPI_WRF} $WRF_CODFILE : -np ${NB_PROC_MPI_ROMS} $ROMS_CODFILE > ${WRF_MODEL}_OASIS-MCT_${ROMS_MODEL}_${TIME}.out
        mpirun -np ${NB_PROC_MPI_WRF} $WRF_CODFILE : -np ${NB_PROC_MPI_ROMS} $ROMS_CODFILE > ${WRF_MODEL}_OASIS-MCT_${ROMS_MODEL}_${TIME}.out
    else
        #echo "Sliced: Check files and enter a key"
        #set JUNKKEY = $<
        #mpiexec -machinefile nodes -np ${NB_PROC_MPI_WRF} $WRF_CODFILE : -np ${NB_PROC_MPI_ROMS} $ROMS_CODFILE  > ${WRF_MODEL}_OASIS-MCT_${ROMS_MODEL}_${TIMEmid}.out  
        mpirun -np ${NB_PROC_MPI_WRF} $WRF_CODFILE : -np ${NB_PROC_MPI_ROMS} $ROMS_CODFILE  > ${WRF_MODEL}_OASIS-MCT_${ROMS_MODEL}_${TIMEmid}.out
    endif
    echo "-- > ***** DONE **** @" `date`
#
#  Archive
#
    set LEVEL=0
    while ($LEVEL != $NLEVEL)
      if (${LEVEL} == 0) then
        set ENDF=
      else
        set ENDF=.${LEVEL}
      endif
      if ($NSLICE == 0) then
          $MV -f ${ROMS_MODEL}_rst.nc${ENDF} ${ROMS_MODEL}_rst_${TIMEnew}.nc${ENDF}
          $LN -sf ${ROMS_MODEL}_rst_${TIMEnew}.nc${ENDF} ${INIFILE}.nc${ENDF}
          #$MV -f ${ROMS_MODEL}_his.nc${ENDF} ${ROMS_MODEL}_his_${TIMEnew}.nc${ENDF}
          $MV -f ${ROMS_MODEL}_avg.nc${ENDF} ${ROMS_MODEL}_avg_${TIMEnew}.nc${ENDF}
          #$CP -f ${OASIS_RSTFILE}.nc ${OASIS_RSTFILE}_${TIMEnew}.nc
          $MV -f  nout.000000  nout.000000_${TIMEnew}  
          $MV -f  debug.root.01  debug.root.01_${TIMEnew}     
          $MV -f  debug.root.02  debug.root.02_${TIMEnew}
          $MV -f  rsl.out.0000  rsl.out.0000_${TIMEnew}
          $MV -f  rsl.error.0000  rsl.error.0000_${TIMEnew}
          #$MV -f  wrfexe.timers_0000  wrfexe.timers_0000_${TIMEnew}
          #$MV -f  crocox.timers_0000  crocox.timers_0000_${TIMEnew}
          if ( ! -e debug.root.02_${TIMEnew}) then
              echo "Planted -- Planted -- Planted"
              set it_is_not_planted = 0
          else
              set test_planted = `grep -n "SUCCESSFUL" debug.root.02_${TIMEnew} | wc -l`
              if ( $test_planted == 0 ) then
                echo "Planted -- Planted -- Planted"
                set it_is_not_planted = 0
              endif
          endif
      else
          $MV -f ${ROMS_MODEL}_rst.nc${ENDF} ${ROMS_MODEL}_rst_${TIMEmid}.nc${ENDF}
          $LN -sf ${ROMS_MODEL}_rst_${TIMEmid}.nc${ENDF} ${INIFILE}.nc${ENDF}
          #$MV -f ${ROMS_MODEL}_his.nc${ENDF} ${ROMS_MODEL}_his_${TIMEmid}.nc${ENDF}
          $MV -f ${ROMS_MODEL}_avg.nc${ENDF} ${ROMS_MODEL}_avg_${TIMEmid}.nc${ENDF}
          #$CP -f ${OASIS_RSTFILE}.nc ${OASIS_RSTFILE}_${TIMEmid}.nc
          $MV -f  nout.000000  nout.000000_${TIMEmid}  
          $MV -f  debug.root.01  debug.root.01_${TIMEmid}     
          $MV -f  debug.root.02  debug.root.02_${TIMEmid}
          $MV -f  rsl.out.0000  rsl.out.0000_${TIMEmid}
          $MV -f  rsl.error.0000  rsl.error.0000_${TIMEmid}
          #$MV -f  wrfexe.timers_0000  wrfexe.timers_0000_${TIMEmid}
          #$MV -f  crocox.timers_0000  crocox.timers_0000_${TIMEmid}
          if ( ! -e debug.root.02_${TIMEmid}) then
              echo "Planted -- Planted -- Planted"
              set it_is_not_planted = 0
          else
              set test_planted = `grep -n "SUCCESSFUL" debug.root.02_${TIMEmid} | wc -l`
              if ( $test_planted == 0 ) then
                echo "Planted -- Planted -- Planted"
                set it_is_not_planted = 0
              endif
          endif
      endif
      @ LEVEL++
    end # end of the loop on LEVEL (ROMS-AGRIF)

# increase the time and determine if the simulation is finished
if  ($NSLICE == 0) then
	@ NM++
	if ($NM > 12 ) then
            set NM = 1
	    @ NY++
	endif
	if ($NY > $NY_END) then
	    set it_is_not_finished = 0
	endif
	if ($NY == $NY_END) then
	    if ($NM > $NM_END) then
		set it_is_not_finished = 0
	    endif
	endif
else
    @ day_mid = $day_mid + $NSLICE
    if ($day_mid > $NDAYS) then
	@ day_mid = $day_mid - $NDAYS
	@ NM++
	if ($NM > 12 ) then
            set NM = 1
	    @ NY++
	endif
    endif
    @ day_beg = $day_mid - $NSLICE / 2
    @ day_end = $day_mid + $NSLICE / 2
    if ($NY > $NY_END) then
	set it_is_not_finished = 0
    endif
    if ($NY == $NY_END) then
	if ($NM > $NM_END) then
	    set it_is_not_finished = 0
	endif
    endif
    if ($NY == $NY_END) then
	if ($NM == $NM_END) then
	   if ($day_mid > $ND_END) then
	       set it_is_not_finished = 0
	   endif
        endif
    endif
endif

if ( $it_is_not_planted == 0 ) then
   set it_is_not_finished = 0
endif

echo "end "
#
end # end of the while loop on the it_is_not_finished
#
#############################################################












