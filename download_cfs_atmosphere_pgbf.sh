#!/usr/bin/env sh

cd /home/cow/for_service_final

# Get current date
current_date=$(date +"%Y%m01")
yy=$(date +"%Y")
mm=$(date +"%m")

# input URL
input_link="https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs."

# make folders
path="/data/datos/COW/cow_v1/pronostico/CFS/"

for hh in {06,12,18}; do
   mkdir -p $path$current_date$hh"/atmosphere/pgbf/"
   #make link for the ocean
   index_ocean=$input_link$current_date"/"$hh"/6hrly_grib_01/"
   # download indexes for the ocean
   wget -q --no-check-certificate $index_ocean -O $path$current_date$hh"/atmosphere/pgbf/index_pgbf.txt"
   # Extract file names: ocean
   grep -e"pgbf"*.*.grb2 $path$current_date$hh"/atmosphere/pgbf/index_pgbf.txt" | cut -d '"' -f 2 | sed 's/\.idx$//' | uniq >> $path$current_date$hh"/atmosphere/pgbf/file_data_atmosphere_pgbf.txt"
   # Download GRIB2 file for the ocean monthly
   while IFS= read -r line; do
      wget -N -c --no-check-certificate $index_ocean$line -P $path$current_date$hh"/atmosphere/pgbf/"
      echo $index_ocean$line
   done < $path$current_date$hh"/atmosphere/pgbf/file_data_atmosphere_pgbf.txt"
done   

