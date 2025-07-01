############################################################################
# Code for plotting time series of precipitation in the El Niño 1+2 region #
############################################################################

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
time_diag = pd.date_range(time_ini, time_mid, freq="3h")
time_diag = time_diag[1:]
time_fore = pd.date_range(time_mid, time_end, freq="3h")
time_fore = time_fore[1:]

# Directories for diagnostic and forecast data
output_dir="/data/datos/COW/cow_v1/analysis/forecasting/figures/"
diag_dir="/data/datos/COW/cow_v1/analysis/diagnostic/cow/"
fore_dir="/data/datos/COW/cow_v1/analysis/forecasting/cow/"+"output_"+time_mid+"_member_01/"
prec_dir="/data/datos/GPM/GPM_IMERG/"

# Load diagnostic and forecast data files
in_diag_atm = glob.glob(os.path.join(diag_dir, f"wrfout_d01_*"))
in_fore_atm = glob.glob(os.path.join(fore_dir, f"wrfout_d01_*"))

# Load diagnostic data files from atmospheric outputs
dd_prec = xr.open_mfdataset(in_diag_atm, concat_dim="Time", combine='nested', parallel=True)
longitude, latitude = dd_prec.XLONG, dd_prec.XLAT
mask = (longitude>-90) & (longitude<-80) & (latitude>-10) & (latitude<0) # cutting in El Niño 1+2 region
mask = mask.where(mask!=0, np.nan)
prec_diag = ((dd_prec.RAINC+dd_prec.RAINNC)*mask).drop_vars("XTIME")
prec_diag["Time"] = time_diag
prec_diag = prec_diag.diff(dim="Time")*8 # each 3 hours-> then we multiply x8 to get in days
del dd_prec

# Resample to monthly means
dd_monthly_prec = prec_diag.resample(Time="ME").mean(dim="Time")
time_monthly_prec_diag = (dd_monthly_prec.mean(dim=["south_north","west_east"])).compute()

# Load forecasting data files from atmospheric outputs
df_prec = xr.open_mfdataset(in_fore_atm, concat_dim="Time", combine='nested', parallel=True)
longitude, latitude = df_prec.XLONG, df_prec.XLAT
mask = (longitude>-90) & (longitude<-80) & (latitude>-10) & (latitude<0)
mask = mask.where(mask!=0, np.nan)
prec_fore = ((df_prec.RAINC+df_prec.RAINNC)*mask).drop_vars("XTIME")
prec_fore["Time"] = time_fore
prec_fore = prec_fore.diff(dim="Time")*8 # each 3 hours-> then we multiply x8 to get in days
del df_prec

# Resample to monthly means
df_monthly_prec = prec_fore.resample(Time="ME").mean(dim="Time")
time_monthly_prec_fore = (df_monthly_prec.mean(dim=["south_north","west_east"])).compute()

# plotting the time series of the precipitation
fmt_month = mdates.MonthLocator()
fmt_year = mdates.YearLocator()

fig, ax = plt.subplots(nrows=1,ncols=1, figsize=(8,6),constrained_layout=True, )
ax.plot(pd.date_range(time_ini, time_mid, freq="MS")[:-1], time_monthly_prec_diag[:-1], label="IGPRESM—COWv1—diagnostico", color="black", linewidth=2)
ax.plot(pd.date_range(time_mid, time_end, freq="MS")[:-1], time_monthly_prec_fore[:-1], label="IGPRESM—COWv1—pronostico", color="red", linewidth=1.6, marker="+", markersize=10)
ax.legend(loc='upper left', fontsize=8, fancybox=False, shadow=False, )
ax.set_title("El Niño  1+2 Prec. (mm) IC ="+str(current_date.strftime('%Y%m')), color="gray", size=20)
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

ax.set_ylim(0, 20)
plt.savefig(output_dir+str(current_date.strftime('%Y%m'))+"_prec.pdf")
#plt.savefig(output_dir+str(current_date.strftime('%Y%m'))+"_prec.png", dpi=500) # modify png by jpg or other 
