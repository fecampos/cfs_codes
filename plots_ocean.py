#####################################################################################
# Code for plotting time series of SST and anomaly of SST in the El Niño 1+2 region #
#####################################################################################

import logging, gsw, time, datetime, os, glob, xgcm, matplotlib, xarray as xr, numpy as np, dask.array as da, pandas as pd
import matplotlib.pyplot as plt, matplotlib.colors as colors, matplotlib.dates as mdates
import cartopy.mpl.ticker as cticker, string, xroms, cartopy.crs as ccrs
import matplotlib.ticker as mticker, xesmf as xe
from dateutil.relativedelta import relativedelta
from datetime import datetime, timedelta, date
import cartopy.feature as cfeature
from matplotlib import animation
from IPython.display import HTML

from dask.distributed import Client, LocalCluster
cluster = LocalCluster(n_workers=40)
client = Client(cluster)

# Set up dates
current_date = datetime.now()
time_mid = current_date.strftime('%Y%m01')
time_ini = current_date.strftime('20240101')
time_end = current_date + relativedelta(months=7)
time_end = time_end.replace(day=1).strftime('%Y-%m-01')
time = pd.date_range(time_ini, time_end, freq="D")
time = time[:-1]
time_diag = pd.date_range(time_ini, time_mid, freq="D")
time_diag = time_diag[:-1]
time_fore = pd.date_range(time_mid, time_end, freq="D")
time_fore = time_fore[:-1]

# Directories for diagnostic and forecast data
output_dir="/data/datos/COW/cow_v1/analysis/forecasting/figures/"
diag_dir="/data/datos/COW/cow_v1/analysis/diagnostic/cow/"
fore_dir="/data/datos/COW/cow_v1/analysis/forecasting/cow/"+"output_"+time_mid+"_member_01/"
clim_dir="/data/datos/COW/cow_v1/analysis/climatology/"

# Load climatology and grid data
ds_out = xr.open_dataset(clim_dir+f"cow4-sst-psud-2000-2023-clima-1anho.nc")
ds_out["time"]=np.arange(12)+1
ds_out["lon"]=ds_out["lon"]-360
ds = xr.open_dataset(diag_dir+f"croco_grd.nc")

# Extract mask, longitude, and latitude
mask, longitude, latitude = ds.mask_rho, ds.lon_rho, ds.lat_rho
mask = ds.mask_rho.where(ds.mask_rho==1,np.nan)

# Define region of interest for masking
mask_roms = (longitude>-90) & (longitude<-80) & (latitude>-10) & (latitude<0)
mask_roms = mask.where(mask_roms==1,np.nan)

# Load diagnostic and forecast data files
in_diag = glob.glob(os.path.join(diag_dir, f"croco_avg_Y*.nc"))
in_fore = glob.glob(os.path.join(fore_dir, f"croco_avg_Y*.nc"))
in_diag_atm = glob.glob(os.path.join(diag_dir, f"wrfout_d01_*"))
in_fore_atm = glob.glob(os.path.join(fore_dir, f"wrfout_d01_*"))

# Open multi-file datasets for diagnostics and forecast
dd_sst = ((xroms.open_mfnetcdf(in_diag, Vtransform=1).isel(s_rho=-1))["temp"]).drop_vars("z_rho")
df_sst = ((xroms.open_mfnetcdf(in_fore, Vtransform=1).isel(s_rho=-1))["temp"]).drop_vars("z_rho")

# Ensure time variables are correctly assigned
dd_sst["time"]=time_diag
df_sst["time"]=time_fore

# Resample to monthly means
dd_monthly_sst = dd_sst.resample(time="MS").mean(dim="time")
df_monthly_sst = df_sst.resample(time="MS").mean(dim="time")

# Compute mean SST values for the defined region of interest
time_diag_sst = (dd_monthly_sst*mask_roms).mean(axis=(1,2)).compute()
time_fore_sst = (df_monthly_sst*mask_roms).mean(axis=(1,2)).compute()

# remove diagnostic and forecasting datasets 
del dd_sst, df_sst

# Regrid to climatology grid
ds_in = ds.rename({"lon_rho": "lon", "lat_rho": "lat"})
regridder = xe.Regridder(ds_in, ds_out, "bilinear")
dr_diag_out = regridder(dd_monthly_sst)
dr_fore_out = regridder(df_monthly_sst)

# Calculate anomalies
asst_fore, asst_diag = [], []

for i in range(time_fore_sst.time.size):
    num = time_fore_sst.time[i].dt.month.item()
    print(num)
    asst_fore.append(dr_fore_out.isel(time=i)-ds_out.sel(time=num))

for i in range(time_diag_sst.time.size):
    num = time_diag_sst.time[i].dt.month.item()
    asst_diag.append(dr_diag_out.isel(time=i)-ds_out.sel(time=num))

# Convert list of anomalies to xarray DataArray
asst_diag = xr.concat(asst_diag, dim='time')
asst_fore = xr.concat(asst_fore, dim='time')

# Assign correct time coordinates
asst_diag["time"] = time_diag_sst.time 
asst_fore["time"] = time_fore_sst.time 

# Apply filters to keep SST values within specified range and El Niño 1+2 region
asst_diag = asst_diag.where((asst_diag.sst <= 6) & (asst_diag.sst >= -4) & (asst_diag.lat > -10) & (asst_diag.lat < 0) & (asst_diag.lon > -90) & (asst_diag.lon < -80), np.nan) 
asst_fore = asst_fore.where((asst_fore.sst <= 6) & (asst_fore.sst >= -4) & (asst_fore.lat > -10) & (asst_fore.lat < 0) & (asst_fore.lon > -90) & (asst_fore.lon < -80), np.nan)
asst_diag.to_netcdf("/data/datos/COW/cow_v1/analysis/forecasting/figures/out.nc")
# Calculate mean anomalies over the specified dimensions
time_asst_diag = (asst_diag.mean(dim=["lon","lat"])).compute()
time_asst_fore = (asst_fore.mean(dim=["lon","lat"])).compute()

# remove anomalies dataset
del asst_diag, asst_fore

# plotting the time series of sea surface temperature
fmt_month = mdates.MonthLocator()
fmt_year = mdates.YearLocator()

fig, ax = plt.subplots(nrows=1,ncols=1, figsize=(8,6),constrained_layout=True, )
ax.plot(pd.date_range(time_ini, time_mid, freq="MS")[:-1], time_diag_sst, label="IGPRESM—COWv1—diagnostico", color="black", linewidth=2)
ax.plot(pd.date_range(time_mid, time_end, freq="MS")[:-1], time_fore_sst, label="IGPRESM—COWv1—pronostico", color="red", linewidth=1.6, marker="+", markersize=10)
ax.legend(loc='upper left', fontsize=8, fancybox=False, shadow=False, )
ax.set_title("El Niño  1+2 TSM (°C) IC ="+str(current_date.strftime('%Y%m')), color="gray", size=20)
ax.set_xlim(datetime.strptime(time_ini, '%Y%m%d'), datetime.strptime(time_end, '%Y-%m-%d'))

ax.xaxis.set_minor_locator(fmt_month)
ax.xaxis.set_minor_formatter(mdates.DateFormatter('%b'))
ax.xaxis.grid(linestyle=":", color="gray")
ax.xaxis.set_major_locator(fmt_year)
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b'))
ax.grid(which='both', linestyle=":", color="gray")

sec_xaxis = ax.secondary_xaxis(-0.07)
sec_xaxis.xaxis.set_major_locator(fmt_year)
sec_xaxis.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
sec_xaxis.spines['bottom'].set_visible(False)

ax.set_ylim(15, 30)
plt.savefig(output_dir+str(current_date.strftime('%Y%m'))+"_sst.pdf")
#plt.savefig(output_dir+str(current_date.strftime('%Y%m'))+"_sst.png", dpi=500) # modify png by jpg or other 

# plotting the time series of the anomaly of sea surface temperature
fig, ax = plt.subplots(nrows=1,ncols=1, figsize=(8,6),constrained_layout=True, )
ax.plot(pd.date_range(time_ini, time_mid, freq="MS")[:-1], time_asst_diag.sst, label="IGPRESM—COWv1—diagnostico", color="black", linewidth=2)
ax.plot(pd.date_range(time_mid, time_end, freq="MS")[:-1], time_asst_fore.sst, label="IGPRESM—COWv1—pronostico", color="red", linewidth=1.6, marker="+", markersize=10)

ax.plot(np.array(time), np.zeros(time.size)+3.0, "--", color="black", linewidth=1)
ax.text(time[10],3.1, "cálido extrordinario", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size)+1.7, "--", color="black", linewidth=1)
ax.text(time[10],1.8, "cálido fuerte", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size)+1, "--", color="black", linewidth=1)
ax.text(time[10],1.1, "cálido moderado", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size)+0.4, "--", color="black", linewidth=1)
ax.text(time[10],0.5, "cálido débil", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size), "-", color="black", linewidth=1)
ax.text(time[10],-0.5, "neutro", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size)-1, "--", color="black", linewidth=1)
ax.text(time[10],-1.1, "frío débil", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size)-1.2, "--", color="black", linewidth=1)
ax.text(time[10],-1.3, "frío moderado", color="black", fontsize=8)

ax.plot(np.array(time), np.zeros(time.size)-1.4, "--", color="black", linewidth=1)
ax.text(time[10],-1.5, "frío fuerte", color="black", fontsize=8)

ax.legend(loc='upper left', fontsize=8, fancybox=False, shadow=False, )
ax.set_title("ICEN El Niño  1+2 TSM (°C) IC ="+str(current_date.strftime('%Y%m')), color="gray", size=20)
ax.set_xlim(datetime.strptime(time_ini, '%Y%m%d'), datetime.strptime(time_end, '%Y-%m-%d'))

ax.xaxis.set_minor_locator(fmt_month)
ax.xaxis.set_minor_formatter(mdates.DateFormatter('%b'))
ax.xaxis.grid(linestyle=":", color="gray")
ax.xaxis.set_major_locator(fmt_year)
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b'))
ax.grid(which='both', linestyle=":", color="gray")

sec_xaxis = ax.secondary_xaxis(-0.07)
sec_xaxis.xaxis.set_major_locator(fmt_year)
sec_xaxis.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
sec_xaxis.spines['bottom'].set_visible(False)

ax.set_ylim(-4, 4)

plt.savefig(output_dir+str(current_date.strftime('%Y%m'))+"_asst.pdf")
#plt.savefig(output_dir+str(current_date.strftime('%Y%m'))+"_asst.png", dpi=500) # modify png by jpg or other 
