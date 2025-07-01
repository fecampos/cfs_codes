#!/bin/sh
source /home/cow/miniforge3/etc/profile.d/conda.sh
export conda=/home/cow/miniforge3/condabin/conda
conda activate env_py
export python=/home/cow/miniforge3/envs/env_py/bin/python

EJEC_WPS="/data/users/cow/PRONOSTICO2/WRF/WPS_4.0"
EJEC_WRF="/data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test"

current_date=$(date +"%Y%m01")
HH=$hh
P=00
PF=00
DD=01
DDf=01

MM=$(date -d "+0 month" +'%m')
MMf=$(date -d "+7 month" +'%m')
YY=$(date -d "+0 month" +'%Y')
YYf=$(date -d "+7 month" +'%Y')

echo $YYf$MMf$DDf$HH

prefigWRFd1="wrfout_d01_"
prefigWRFd2="wrfout_d02_"
prefigWRFd3="wrfout_d03_"
posfigWRF="_00:00:00"

prefigARWd1="ARWout_d01_"
prefigARWd2="ARWout_d02_"
prefigARWd3="ARWout_d03_"

prefigGFS="GFS-grib2_ac_"

DOM1="d01"
DOM2="d02"
DOM3="d03"

fileInt="namelist.wps"
fileOut="namelistOut.wps"

cp -r $EJEC_WPS/PSUD_3_CFS_MONTH_2024020100_DAFIOBAK $EJEC_WPS/PSUD_3_CFS_MONTH_$current_date${HH}_new

echo "Haciendo link"
echo "Editando fichero namelist.wps"

cd $EJEC_WPS/PSUD_3_CFS_MONTH_$current_date${HH}_new

#############Editar fichero namelist.wps###########

#Calculando los metfiles para los niveles de presión
./link_grib.csh $atm_pgbf_path/pgbf*

scp namelist.wps_Press namelist.wps
scp Vtable.CFSR_press_pgbh06 Vtable
sed -e '1,5s/ start_date = .*/ start_date = '\'''$YY'-'$MM'-'$DD'_00:00:00'\'','\'''$YY''-''$MM''-''$DD'_00:00:00'\'','\'''$YY'-'$MM'-'$DD'_00:00:00'\'','\'''$YY'-'$MM'-'$DD'_00:00:00'\'','\'''$YY'-'$MM'-'$DD'_00:00:00'\'',/g' $fileInt > $fileOut
rm $fileInt
mv  $fileOut $fileInt
####
sed -e '1,5s/ end_date   = .*/ end_date   = '\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'','\'''$YYf''-''$MMf''-''$DDf'_00:00:00'\'','\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'','\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'','\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'',/g' $fileInt > $fileOut
rm $fileInt
mv  $fileOut $fileInt
echo "Terminado editado fichero namelist.wps"
echo "Comenzando el ungrib"
./ungrib.exe
echo "Terminado el ungrib"
############################################################################################################################
#Calculando los metfiles para los flujos de superficie
./link_grib.csh $atm_flxf_path/flxf*

scp namelist.wps_sfc namelist.wps
scp Vtable.CFSR_sfc_flxf06 Vtable
sed -e '1,5s/ start_date = .*/ start_date = '\'''$YY'-'$MM'-'$DD'_00:00:00'\'','\'''$YY''-''$MM''-''$DD'_00:00:00'\'','\'''$YY'-'$MM'-'$DD'_00:00:00'\'','\'''$YY'-'$MM'-'$DD'_00:00:00'\'','\'''$YY'-'$MM'-'$DD'_00:00:00'\'',/g' $fileInt > $fileOut
rm $fileInt
mv  $fileOut $fileInt
####
sed -e '1,5s/ end_date   = .*/ end_date   = '\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'','\'''$YYf''-''$MMf''-''$DDf'_00:00:00'\'','\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'','\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'','\'''$YYf'-'$MMf'-'$DDf'_00:00:00'\'',/g' $fileInt > $fileOut
rm $fileInt
mv  $fileOut $fileInt
echo "Terminado editado fichero namelist.wps"
echo "Comenzando el ungrib"  
./ungrib.exe
echo "Terminado el ungrib"

#Renombrar archivos de salida de ungrib
sed -e 's/YYMMDD/'$current_date'/g' -e 's/HH/'$HH'/g' run_levels_bs.sh-template > run_levels_bs_fecg.sh
chmod +x run_levels_bs_fecg.sh
./run_levels_bs_fecg.sh

#Ejecutando metgrid #
./metgrid.exe
echo "Terminado el metgrid"

cp -r $EJEC_WRF/em_real $EJEC_WRF/PSUD_3_CFS_MONTH_$current_date$HH"_new"

cd $EJEC_WRF/PSUD_3_CFS_MONTH_$current_date$HH"_new"

ln -sf $EJEC_WPS/PSUD_3_CFS_MONTH_$current_date${HH}"_new/"met_em* $EJEC_WRF/PSUD_3_CFS_MONTH_$YY$MM$DD${HH}_new
##############################
#Realizar la corrección climática

#python DC_mets_mensual_fe_new.py
#sed -e 's/YYMMDD/'$current_date'/g' -e 's/HH/'$HH'/g' -e 's/hh/'$hh'/g' /home/cow/DC_mets_mensual_fe_template.py > /home/cow/DC_mets_mensual_fe_new.py
cd /home/cow/
python DC_mets_mensual_$current_date$HH.py

cp -r $EJEC_WRF/em_real $EJEC_WRF/PSUD_3_CFS_MONTH_$current_date${HH}_new/

cd $EJEC_WRF/PSUD_3_CFS_MONTH_$current_date${HH}_new

ln -sf /data/users/cow/PRONOSTICO2/WRF/WPS_4.0/PSUD_3_CFS_MONTH_$current_date${HH}_new/METS_CORREG/met_em* /data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test/PSUD_3_CFS_MONTH_$current_date${HH}_new
ln -s  /home/cow/experimentos/secundary_files/bash/join_to_monthly_data_wrf_forecasting.sh join_to_monthly_data_wrf_forecasting.sh 
cp /home/cow/experimentos/main_files/namelist.input_temple_sl4_sf1_nml24 namelist.input_temple_sl4_sf1_nml24
./join_to_monthly_data_wrf_forecasting.sh

#############Editar fichero namelist.input###########
#fileInt="namelist.input_"$YY$MM
#fileOut="namelistOut.input"
#echo "Editando fichero namelist.input"
#sed -e '1,20s/ start_year                          = .*/ start_year                          = '$YY', '$YY', '$YY', '$YY', '$YY',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ start_month                         = .*/ start_month                         = '$MM',   '$MM',   '$MM',   '$MM',   '$MM',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ start_day                           = .*/ start_day                           = '$DD',   '$DD',   '$DD',   '$DD',   '$DD',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ start_hour                          = .*/ start_hour                          = '$P',   '$P',   '$P',   '$P',   '$P',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
################@@@@@@@@@@@@@@@@@@@@@#####################
#sed -e '1,20s/ end_year                            = .*/ end_year                            = '$YYf', '$YYf', '$YYf', '$YYf', '$YYf',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ end_month                           = .*/ end_month                           = '$MMf',   '$MMf',   '$MMf',   '$MMf',   '$MMf',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ end_day                             = .*/ end_day                             = '$DDf',   '$DDf',   '$DDf',   '$DDf',   '$DDf',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ end_hour                            = .*/ end_hour                            = '$P',   '$P',   '$P',   '$P',   '$P',/g' $fileInt > $fileOut
#rm $fileInt
#mv  $fileOut $fileInt
####
#sed -e '1,20s/ interval_seconds                    = .*/ interval_seconds                    = '21600',/g' $fileInt > $fileOut
#mv  $fileOut $fileInt
#Ejecutando el real.exe
echo "namelist.input_"$YY$MM
cp "namelist.input_"$YY$MM "namelist.input"
./real.exe
sleep 10m

mv wrfbdy_d01 wrfbdy_d01_$YY$MM
mv wrffdda_d01 wrffdda_d01_$YY$MM
mv wrfinput_d01 wrfinput_d01_$YY$MM
mv wrflowinp_d01 wrflowinp_d01_$YY$MM

cp -r "/data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test/PSUD_3_CFS_MONTH_"$current_date$HH"_new/wrfbdy_d01_"* /data/datos/COW/cow_v1/new_cow/data_CFS/cow/2017/atmosphere
cp -r "/data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test/PSUD_3_CFS_MONTH_"$current_date$HH"_new/wrffdda_d01_"* /data/datos/COW/cow_v1/new_cow/data_CFS/cow/2017/atmosphere
cp -r "/data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test/PSUD_3_CFS_MONTH_"$current_date$HH"_new/wrfinput_d01_"* /data/datos/COW/cow_v1/new_cow/data_CFS/cow/2017/atmosphere
cp -r "/data/users/cow/PRONOSTICO2/WRF/WRF_4.0/test/PSUD_3_CFS_MONTH_"$current_date$HH"_new/wrflowinp_d01_"* /data/datos/COW/cow_v1/new_cow/data_CFS/cow/2017/atmosphere

#mv wrfbdy_d01 wrfbdy_d01_$YY$MM
#mv wrffdda_d01 wrffdda_d01_$YY$MM
#mv wrfinput_d01 wrfinput_d01_$YY$MM
#mv wrflowinp_d01 wrflowinp_d01_$YY$MM

#cd $EJEC_WRF/
#scp wrfbdy_d01 wrfbdy_d01_$YY$MM /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files
#scp wrffdda_d01 wrffdda_d01_$YY$MM /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files
#scp wrfinput_d01 wrfinput_d01_$YY$MM /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files
#scp wrflowinp_d01 wrflowinp_d01_$YY$MM /data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files

exit

