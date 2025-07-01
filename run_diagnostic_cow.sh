#!/bin/bash

# Code to run the coupled ocean-atmosphere simulation in diagnostic mode:
# Questions about the code to Fernando Campos (fcampos@cicese.edu.mx)

source /etc/profile.d/modules.sh

export MODULEPATH=/xhome/usuario/modules/compilers:/xhome/usuario/modules/libraries/generic

export MODULECONFIGFILE=/xhome/usuario/modules/config/modulerc

module load intel/16.0.3
module load intel_netcdf/4.4.3
module load intel_ompi/1.10.6

export PATH=/usr/local/slurm/bin:$PATH

cd /home/cow/for_service_final

source /home/cow/miniforge3/etc/profile.d/conda.sh

conda activate copernicusmarine

# load matlab library
matlabdir='/opt/matlab/R2016b/bin/matlab'

# read copernicus user and password
export COPERNICUSMARINE_DISABLE_SSL_CONTEXT=True
export COPERNICUSMARINE_SERVICE_USERNAME=fcampos
export COPERNICUSMARINE_SERVICE_PASSWORD=AAAbbb111@@@

# read data from 1 month ago
date=$(date -d "1 month ago" +'%Y-%m')
YY=$(date -d "1 month ago" +'%Y')
echo $date

# link ocean and atmosphere paths
diag_ocean_path="/data/datos/COW/cow_v1/analysis/diagnostic/ocean/"
diag_atmosphere_path="/data/datos/COW/cow_v1/analysis/diagnostic/atmosphere/"

# average from daily to monthly data
echo "1) average from daily to monthly data"
ln -sf /home/cow/cow_peru/codes/from_daily-to_monthly.py from_daily-to_monthly.py
python from_daily-to_monthly.py
rm from_daily-to_monthly.py

# remap, cut and change in data
echo "2) remap, cut and change in date"
commands="-P 40 -s -b F32 -setmissval,-1.e+20 -setreftime,1980-01-01,0,1day -setcalendar,standard -sellonlatbox,-180.0,-70.0,-30.0,10.0 -remapcon,r720x360"
cdo $commands $diag_ocean_path"psy4v3_"$date"_monthly.nc" $diag_ocean_path"psy4v3_"$date"_med_reso_stand_mis_float.nc"

# call matlab library for making ocean boundaries
echo "3) call matlab library for making ocean boundaries"
$matlabdir -nodesktop -nosplash -r "run('/data/datos/COW/cow_v1/tools/Run/make_OGCM_mydata_diagnostic_cow.m'); exit;"
sleep 5m

# call wrf library form making atmosphere boundaries
echo "4) call wrf library form making atmosphere boundaries"
ln -sf /home/cow/cow_peru/codes/run_wrf_diagnostic.sh run_wrf_diagnostic.sh
./run_wrf_diagnostic.sh
rm run_wrf_diagnostic.sh
echo "hast aqui hemos llegado"

# run the COW
echo "5) run the cow simulation"
ln -sf /home/cow/cow_peru/codes/run_cow_diag.csh run_cow_diag.csh

# Enviar el trabajo con sbatch y capturar el Job ID
job_id=$(/usr/local/slurm/bin/sbatch run_cow_diag.csh | awk '{print $4}')

echo "Job ID: $job_id"
# Esperar a que el trabajo termine
while squeue -j $job_id > /dev/null 2>&1; do
    sleep 1
done

rm -r run_cow_diag.csh

echo "Continuando con el resto del script."
MM=$(date -d "1 month ago" +'%m')
scp "/data/datos/COW/cow_v1/analysis/diagnostic/cow/croco_rst_Y"$YY"M"$MM".nc" "/data/datos/COW/cow_v1/analysis/diagnostic/ocean/croco_files/"
scp "/data/datos/COW/cow_v1/analysis/diagnostic/cow/croco_rst_Y"$YY"M"$MM".nc" "/data/datos/COW/cow_v1/analysis/forecasting/ocean/croco_files/"

MM=$(date -d "now" +'%m')
scp "/data/datos/COW/cow_v1/analysis/diagnostic/cow/wrfrst_d01_"$YY"-"$MM"-01_00:00:00" "/data/datos/COW/cow_v1/analysis/diagnostic/atmosphere/wrf_files/"
scp "/data/datos/COW/cow_v1/analysis/diagnostic/cow/wrfrst_d01_"$YY"-"$MM"-01_00:00:00" "/data/datos/COW/cow_v1/analysis/forecasting/atmosphere/wrf_files/"

echo "terminado todo.. prosigue al pronostico"
