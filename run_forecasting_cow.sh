#!/bin/bash

# Code to run the coupled ocean-atmosphere simulation in forecasting mode:
# Questions about the code to Fernando Campos (fcampos@cicese.edu.mx)

source /etc/profile.d/modules.sh

export MODULEPATH=/xhome/usuario/modules/compilers:/xhome/usuario/modules/libraries/generic

export MODULECONFIGFILE=/xhome/usuario/modules/config/modulerc

module load intel/16.0.3
module load intel_netcdf/4.4.3
module load intel_ompi/1.10.6
module load cdo/1.7.2
module load nco/4.6.5

export PATH=/usr/local/slurm/bin:$PATH

cd /home/cow/for_service_final

source /home/cow/miniforge3/etc/profile.d/conda.sh

conda activate copernicusmarine

# load matlab library
matlabdir='/opt/matlab/R2016b/bin/matlab'

# Get current date
current_date=$(date +"%Y%m01")
time0=$(date +"%-m")
mm=$(date +"%m")

# write u and v name
uu="ocu" #"ucurr"
vv="ocv" #"vcurr"
grb2="grb2"

# read command used in cdo
command="-setmissval,-1.e+20 -setreftime,1980-01-01,0,1day -setcalendar,standard -sellonlatbox,-180.0,-70.0,-30.0,10.0 -remapcon,r720x360"

# copying data from 00h to 06h, 12h and 18h:
large_path="/data/datos/COW/cow_v1/pronostico/CFS/data02/"
for hh in {06,12,18}; do
  cp $large_path$current_date"00/atmosphere/pgbf/pgbf"$current_date"00.01."$current_date"00.grb2" $large_path$current_date$hh"/atmosphere/pgbf/pgbf"$current_date"00.01."$current_date$hh".grb2"
  cp $large_path$current_date"00/atmosphere/flxf/flxf"$current_date"00.01."$current_date"00.grb2" $large_path$current_date$hh"/atmosphere/flxf/flxf"$current_date"00.01."$current_date$hh".grb2"
done

for hh in {12,18}; do
  cp $large_path$current_date"00/atmosphere/pgbf/pgbf"$current_date"06.01."$current_date"00.grb2" $large_path$current_date$hh"/atmosphere/pgbf/pgbf"$current_date"06.01."$current_date$hh".grb2"
  cp $large_path$current_date"00/atmosphere/flxf/flxf"$current_date"06.01."$current_date"00.grb2" $large_path$current_date$hh"/atmosphere/flxf/flxf"$current_date"06.01."$current_date$hh".grb2"
done

hh=18
cp $large_path$current_date"00/atmosphere/pgbf/pgbf"$current_date"12.01."$current_date"00.grb2" $large_path$current_date$hh"/atmosphere/pgbf/pgbf"$current_date"12.01."$current_date$hh".grb2"
cp $large_path$current_date"00/atmosphere/flxf/flxf"$current_date"12.01."$current_date"00.grb2" $large_path$current_date$hh"/atmosphere/flxf/flxf"$current_date"12.01."$current_date$hh".grb2"

# processing boundary conditions for ocean component for each member:
for hh in {00,06}; do
   oce_path="/data/datos/COW/cow_v1/pronostico/CFS/data02/$current_date$hh/ocean/"
   atm_pgbf_path="/data/datos/COW/cow_v1/pronostico/CFS/data02/$current_date$hh/atmosphere/pgbf/"
   atm_flxf_path="/data/datos/COW/cow_v1/pronostico/CFS/data02/$current_date$hh/atmosphere/flxf/"
   time_ini=$(date +"%-m") #$time0
   index=1
   while IFS= read -r line; do
      echo $oce_path$line
      # Convert GRIB2 to NetCDF using cdo
      cdo -P 40 -O -f nc copy $oce_path"/"$line $oce_path"/"$line.nc
      # Cut variables from NetCDF: salinity, temperature, u,v, ssh
      ncks -O -v pt,s,$uu,$vv,sshg $oce_path"/"$line.nc $oce_path"/"$line.nc
      # change temperature and salinity
      ncap2 -O -s "pt=pt-273.15" -s "s=s*1000" -s "time=time+15+30*$time0" $oce_path"/"$line.nc $oce_path"/"$line.nc
      # add off_set and changing units of temperature
      ncatted -O -h -a add_offset,pt,m,f,25. -a units,pt,m,c,"degrees_C" $oce_path"/"$line.nc
      # change name of variables and dimensions, and temperature as float variable
      ncrename -O -v pt,thetao -v s,so -v $uu,uo -v $vv,vo -v sshg,zos -v lon,longitude -v lat,latitude $oce_path"/"$line.nc $oce_path"/"$line.nc
      ncrename -O -d lon,longitude -d lat,latitude $oce_path"/"$line.nc $oce_path"/"$line.nc
      # permute depth dimension
      ncpdq -O -a -depth $oce_path"/"$line.nc $oce_path"/"$line.nc
      # change start time and remapping 
      cdo -O -P 40 -s $command $oce_path"/"$line.nc $oce_path"/"$line"_v02.nc"
      # overwrite data
      mv $oce_path"/"$line"_v02.nc" $oce_path"/"$line"_corr.nc"

      ####################
      # climate difference
      ####################
      if [ $time0 == $time_ini ]; then
         echo "initial time=$time_ini"
         ncap2 -O -s "thetao=float(thetao)" $oce_path"/"$line"_corr.nc" $oce_path"/"$line"_corr.nc"
      else
         # extract specific months from CFS data
         path="/data/datos/COW/cow_v1/climatology/ncei_8210/$mm/D01_H$hh/OCN_IVONNE/"
         cdo -O -P 40 -s $command $path"ocnf.$mm.01.$hh.l0$index.fclm.1982.2010.grb2_new.nc" $oce_path"cfs_correction.nc"         
         # cfs correction in data: T1=T_{pronos}-T_{CFS clim}
         ncdiff -O -t 40 $oce_path"/"$line"_corr.nc" $oce_path"cfs_correction.nc" $oce_path"/"$line"_corr.nc"
         # return to classic netcdf
         ncks -O -3 $oce_path"/"$line"_corr.nc" $oce_path"/"$line"_corr.nc"
         ncap2 -O -s "thetao=float(thetao)" $oce_path"/"$line"_corr.nc" $oce_path"/"$line"_corr.nc"
         # month index from 0 until 11 [1-12]:
         ii=$time0
         # extract specific month using time index ii from mercator correction
         cp "/data/datos/COW/cow_v1/climatology/clim_glorys_month_$(printf "%02d" "$ii").nc" $oce_path"mercator_correction.nc"
         # mercator correction in data: T_{correct}=T1+T_{mercator}
         ncbo -O -t 40 --op_typ=add $oce_path"/"$line"_corr.nc" $oce_path"mercator_correction.nc" $oce_path"/"$line"_corr.nc"
         ncap2 -O -s "thetao=float(thetao)" $oce_path"/"$line"_corr.nc" $oce_path"/"$line"_corr.nc"
      fi
      rm $oce_path"cfs_correction.nc" $oce_path"mercator_correction.nc"
      ####################
          
      if [ $time0 -gt 11 ]; then
         time0=0
      fi
      if [ $index == 7 ]; then
         break
      fi
      time0=$(($time0 + 1))
      index=$(($index + 1))
   done < $oce_path"file_data_ocean.txt"
   cp $oce_path/*_corr.nc /data/datos/COW/cow_v1/analysis/forecasting/ocean/
   $matlabdir -nodesktop -nosplash -r "run('/data/datos/COW/cow_v1/tools/Run/make_OGCM_mydata_forecasting_cow_member01.m'); exit;"
   sleep 6m 
   cp -r /data/datos/COW/cow_v1/analysis/forecasting/ocean/croco_files /data/datos/COW/cow_v1/analysis/forecasting/ocean/croco_files_$current_date$hh
   sleep 5m
   rm "/data/datos/COW/cow_v1/analysis/forecasting/ocean/croco_files/croco_bry_"*".nc"
   rm "/data/datos/COW/cow_v1/analysis/forecasting/ocean/ocnf.01.$current_date$hh"*".nc"
   rm "/data/datos/COW/cow_v1/analysis/forecasting/ocean/cfs_"*".cdf"
done

# processing boundary conditions for atmospheric component for each member:
for hh in {00,06}; do
   echo $hh
   atm_pgbf_path="/data/datos/COW/cow_v1/pronostico/CFS/data02/$current_date$hh/atmosphere/pgbf/"
   atm_flxf_path="/data/datos/COW/cow_v1/pronostico/CFS/data02/$current_date$hh/atmosphere/flxf/"
   ln -sf /home/cow/cow_peru/codes/run_wrf_forecasting_template.sh run_wrf_forecasting.sh
   sed -i 's/HH=$hh/HH='$hh'/' run_wrf_forecasting.sh
   sed -i 's|$atm_pgbf_path/pgbf|'$atm_pgbf_path"pgbf"'|' run_wrf_forecasting.sh  
   sed -i 's|$atm_flxf_path/flxf|'$atm_flxf_path"flxf"'|' run_wrf_forecasting.sh  
   sed -e 's/YYMMDD/'$current_date'/g' -e 's/HH/'$hh'/g' -e 's/hh/'$hh'/g' /home/cow/DC_mets_mensual_fe_template.py > /home/cow/DC_mets_mensual_$current_date$hh.py
   ./run_wrf_forecasting.sh
   cp -r /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files "/data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files_"$current_date$hh
   rm -r /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files/wrfbdy_d01_*
   rm -r /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files/wrffdda_d01_*
   rm -r /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files/wrfinput_d01_*
   rm -r /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files/wrflowinp_d01_*
   rm -r "/data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test/PSUD_3_CFS_MONTH_"$current_date$hh"_new"
   rm -r "/data/users/cow/PRONOSTICO2/WRF/WPS_4.0/PSUD_3_CFS_MONTH_"$current_date$hh"_new"
   rm run_wrf_forecasting.sh  
done


# running cow simulation for each member:
for hh in {00,06}; do
   mkdir '/data/datos/COW/cow_v1/analysis/forecasting/cow/output_'$current_date$hh
   cp /home/cow/cow_peru/codes/run_cow_forecasting_template.csh run_cow_fore_$current_date$hh.csh
   sed -i 's|SCRATCHDIR=$cow_link_member|SCRATCHDIR=/data/datos/COW/cow_v1/analysis/forecasting/cow/output_'$current_date$hh'|' run_cow_fore_$current_date$hh.csh
   sed -i 's|ROMS_MSSDIR=$roms_link_member|ROMS_MSSDIR=/data/datos/COW/cow_v1/analysis/forecasting/ocean/croco_files_'$current_date$hh'|' run_cow_fore_$current_date$hh.csh
   sed -i 's|WRF_MSSDIR=$wrf_link_member|WRF_MSSDIR=/data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files_'$current_date$hh'|' run_cow_fore_$current_date$hh.csh 
   sbatch run_cow_fore_$current_date$hh.csh  
done


