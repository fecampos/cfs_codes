#!/bin/sh -l
#####################################################
# reseña:
# codigo escrito para la descarga diaria de la base 
# de datos de copernicus
#####################################################

cd /home/cow/for_service_final/

source /home/cow/miniforge3/etc/profile.d/conda.sh

conda activate copernicusmarine

export COPERNICUSMARINE_DISABLE_SSL_CONTEXT=True
export COPERNICUSMARINE_SERVICE_USERNAME=fcampos
export COPERNICUSMARINE_SERVICE_PASSWORD=AAAbbb111@@@

current_date=$(date -d "5 day ago" +'%Y-%m-%d')
output_path="/data/datos/COW/cow_v1/diagnostico/merator/"


echo "Downloading data for $current_date"

# Intenta descargar hasta que tenga éxito
while true; do
  echo "Processing date: $current_date"

  echo "downloading ssh ..."
  if copernicusmarine subset -i cmems_mod_glo_phy_anfc_0.083deg_P1D-m --minimum-longitude -180.0 --maximum-longitude -70.0 --minimum-latitude -30.0 --maximum-latitude 10.0 --minimum-depth 0.45 --maximum-depth 5800 --variable zos --start-datetime "$current_date"T00:00:00 --end-datetime "$current_date"T23:00:00 --output-directory $output_path --output-filename "ssh_$current_date.nc" --service geoseries --force-download --overwrite-output-data --no-metadata-cache --netcdf3-compatible --overwrite-output-data; then
    echo "SSH data downloaded successfully."
    break
  else
    echo "Failed to download SSH data. Retrying in 30 minutes..."
    sleep 180 # Espera 30 minutos
  fi
done

# Repite el mismo patrón para las otras descargas
while true; do
  echo "downloading currents ..."
  if copernicusmarine subset -i cmems_mod_glo_phy-cur_anfc_0.083deg_P1D-m --minimum-longitude -180.0 --maximum-longitude -70.0 --minimum-latitude -30.0 --maximum-latitude 10.0 --minimum-depth 0.45 --maximum-depth 5800 --variable uo --variable vo --start-datetime "$current_date"T00:00:00 --end-datetime "$current_date"T23:00:00 --output-directory $output_path --output-filename "currents_$current_date.nc" --service geoseries --force-download --overwrite-output-data --no-metadata-cache --netcdf3-compatible --overwrite-output-data; then
    echo "Currents data downloaded successfully."
    break
  else
    echo "Failed to download currents data. Retrying in 30 minutes..."
    sleep 180
  fi
done

while true; do
  echo "downloading salinity ..."
  if copernicusmarine subset -i cmems_mod_glo_phy-so_anfc_0.083deg_P1D-m --minimum-longitude -180.0 --maximum-longitude -70.0 --minimum-latitude -30.0 --maximum-latitude 10.0 --minimum-depth 0.45 --maximum-depth 5800 --variable so --start-datetime "$current_date"T00:00:00 --end-datetime "$current_date"T23:00:00 --output-directory $output_path --output-filename "salinity_$current_date.nc" --service geoseries --force-download --overwrite-output-data --no-metadata-cache --netcdf3-compatible --overwrite-output-data; then
    echo "Salinity data downloaded successfully."
    break
  else
    echo "Failed to download salinity data. Retrying in 30 minutes..."
    sleep 180
  fi
done

while true; do
  echo "downloading temperature ..."
  if copernicusmarine subset -i cmems_mod_glo_phy-thetao_anfc_0.083deg_P1D-m --minimum-longitude -180.0 --maximum-longitude -70.0 --minimum-latitude -30.0 --maximum-latitude 10.0 --minimum-depth 0.45 --maximum-depth 5800 --variable thetao --start-datetime "$current_date"T00:00:00 --end-datetime "$current_date"T23:00:00 --output-directory $output_path --output-filename "temperature_$current_date.nc" --service geoseries --force-download --overwrite-output-data --no-metadata-cache --netcdf3-compatible --overwrite-output-data; then
    echo "Temperature data downloaded successfully."
    break
  else
    echo "Failed to download temperature data. Retrying in 30 minutes..."
    sleep 180
  fi
done

ln -s /home/cow/experimentos/secundary_files/python/merge_data_psy4v3.py /home/cow/for_service/merge_data_psy4v3.py
python /home/cow/for_service/merge_data_psy4v3.py $current_date
rm /home/cow/for_service/merge_data_psy4v3.py

# remove netcdf files with each variable
rm $output_path"ssh_"$current_date".nc" $output_path"currents_"$current_date".nc" $output_path"temperature_"$current_date".nc" $output_path"salinity_"$current_date".nc"

