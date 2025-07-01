#!/usr/bin/env sh

cd /home/cow/for_service_final

# Get current date
current_date=$(date +"%Y%m01")
yy=$(date +"%Y")
mm=$(date +"%m")

# input URL
input_link="https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs."

# make folders
path="/data/datos/COW/cow_v1/pronostico/CFS/data02/"

for hh in {00,06,12,18}; do
   mkdir -p $path$current_date$hh"/ocean"
   #make link for the ocean
   index_ocean=$input_link$current_date"/"$hh"/monthly_grib_01/"
   # download indexes for the ocean
   wget -q --no-check-certificate $index_ocean -O $path$current_date$hh"/ocean/index_ocean.txt"
   # Extract file names: ocean
   grep -e"ocnf.01."*"${current_date}".*"avrg.grib.grb2" $path$current_date$hh"/ocean/index_ocean.txt" | cut -d '>' -f 2 | cut -d '<' -f 1 | sed 's/\.idx$//' | uniq >> $path$current_date$hh"/ocean/file_data_ocean.txt"
   # Download GRIB2 file for the ocean monthly
   while IFS= read -r line; do
      wget -N -c --no-check-certificate $index_ocean$line -P $path$current_date$hh"/ocean/"
      echo $index_ocean$line
   done < $path$current_date$hh"/ocean/file_data_ocean.txt"
done   

