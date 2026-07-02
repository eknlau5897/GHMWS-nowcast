#!/bin/bash

BRANCH="main"
githubUser="eknlau5897"
githubRepo="GHMWS-nowcast"

# Explicitly match your path structure from the file tree
IMAGE_OUT_DIR="./swirls"
mkdir -p "$IMAGE_OUT_DIR"

echo "=================================================================="
echo "   HKO GRIDDED NOWCAST DYNAMICS ENGINE (STRICT TREE STORAGE)     "
echo "=================================================================="

while true; do
    echo "--- 任務開始: $(date) ---"

    # ==============================================================================
    # 1. PYTHON HKO RADAR ANALYSIS MATRIX
    # ==============================================================================
    python3.11 << 'EOF_PYTHON'
import os
import pandas as pd 
import xarray as xr
from PIL import Image
import matplotlib.pyplot as plt
import numpy as np
from urllib.request import urlopen
import cartopy.feature as cfeature
import cartopy.crs as ccrs
import datetime as dt
from herbie import Herbie
from herbie.toolbox import EasyMap, pc
from herbie import paint

try:
    url="https://data.weather.gov.hk/weatherAPI/hko_data/F3/Gridded_rainfall_nowcast.csv"
    data=pd.read_csv(url)

    latitude=np.array(np.linspace(23.487,21.328,121))
    longitude=np.array(np.linspace(112.956,115.291,121))
    X,Y=np.meshgrid(longitude,latitude)
    ds_1=data['Half-hourly Nowcast Accumulated Rainfall (mm)'][0:14641]
    ds_1=np.expand_dims(ds_1,axis=-1)
    ds_1=np.reshape(ds_1,(121,121))
    ds_2=data['Half-hourly Nowcast Accumulated Rainfall (mm)'][14641:29282]
    ds_2=np.expand_dims(ds_2,axis=-1)
    ds_2=np.reshape(ds_2,(121,121))

    condition_1=data['Latitude (degree)']<22.14
    condition_2=data['Latitude (degree)']>22.57
    condition_3=data['Longitude (degree)']<113.83
    condition_4=data['Longitude (degree)']>114.43
    rows_to_drop = data[condition_1|condition_2|condition_3|condition_4].index
    df_cleaned= data.drop(rows_to_drop)

    df_cleaned_1=np.expand_dims(df_cleaned[0:744]['Half-hourly Nowcast Accumulated Rainfall (mm)'],axis=-1)
    ds_5=np.reshape(df_cleaned_1,(24,31))
    df_cleaned_2=np.expand_dims(df_cleaned[744:1488]['Half-hourly Nowcast Accumulated Rainfall (mm)'],axis=-1)
    ds_6=np.reshape(df_cleaned_2,(24,31))
    percent_10=((ds_5+ds_6)>=10).mean()
    percent_30=((ds_5+ds_6)>=30).mean()
    percent_50=((ds_5+ds_6)>=50).mean()
    percent_70=((ds_5+ds_6)>=70).mean()
    percent_100=((ds_5+ds_6)>=100).mean()
    percent_140=((ds_5+ds_6)>=140).mean()

    import matplotlib.font_manager
    matplotlib.rcParams['font.family'] = ['PingFang HK']
    import matplotlib as mpl
    proj = ccrs.PlateCarree()

    fig = plt.figure(figsize=(12,12),layout='constrained')
    ax = plt.axes(projection=proj)

    ax.add_feature(cfeature.STATES.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.BORDERS.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.COASTLINE.with_scale('10m'), linewidths=1.0, linestyle='solid', edgecolor='k')
    ax.add_feature(cfeature.OCEAN)
    ax.add_feature(cfeature.LAND.with_scale('10m'),facecolor='#EEEEEE')
    ax.tissot(rad_km=(50), lons=[114.175], lats=[22.3], alpha=0.2,color=None,linewidth=1,edgecolor='red')
    ax.tissot(rad_km=(100), lons=[114.175], lats=[22.3], alpha=0.2,color=None,linewidth=1,edgecolor='orange')
    ax.plot([114.416,113.832,113.832,114.416,114.416],[22.555,22.555,22.142,22.142,22.555],'-',linewidth=1,color='red',transform=ccrs.PlateCarree())
    ax.plot([115.291,112.956,112.956,115.291,115.291],[23.487,23.487,21.328,21.328,23.487],'-',linewidth=1,color='blue',transform=ccrs.PlateCarree())

    c=ax.contour(X,Y,(ds_1+ds_2),levels=[0.1,1,5,10,20,30,50,70,100,140],colors=['cyan','white','blue','yellow','gold','orange','red','k','violet','indigo'],transform=pc)
    cf=ax.contourf(X,Y,(ds_1+ds_2),levels=np.arange(0.1,170,0.1),cmap='radar.reflectivity',transform=pc)
    ax.clabel(c,fontsize=10, inline=1, inline_spacing=1, rightside_up=True)
    cb = fig.colorbar(cf, ax=ax, orientation='horizontal', shrink=0.74, pad=0)
    cb.set_label('mm', size='x-large')
    gl=ax.gridlines(draw_labels=True)
    gl.xlabels_bottom = True
    gl.ylabels_left = True
    ax.set_extent([112.956,115.291,21.328,23.487])
    ax.set_title(f"HKO 香港網格點臨近降雨預報（1小時）\n紅框範圍內：\n>=10mm/hr百分比：{float(percent_10*100)}%\n>=30mm/hr百分比：{float(percent_30*100)}%\n>=50mm/hr百分比：{float(percent_50*100)}%\n>=70mm/hr百分比：{float(percent_70*100)}%\n>=100mm/hr百分比：{float(percent_100*100)}%\n>=140mm/hr百分比：{float(percent_140*100)}%\nPlotted by GHMWS\ndata from HKO open data",size=16,loc='left')
    ax.set_title(f"開始時間：{data['Updated Date and Time (in Hong Kong Time)'][0]}\n結束時間：{data['Ending Date and Time (in Hong Kong Time)'][14641]}\nMax:{float(np.max(ds_1+ds_2))}mm",loc='right',size=16)
    
    # Save directly to the relative swirls directory
    plt.savefig('./swirls/img_2d.png')
    plt.close()
    print("📈 Python Render Complete Engine Success.")
except Exception as e:
    print(f"❌ Python Data Processing Error: {e}")
EOF_PYTHON

    # ==============================================================================
    # 2. STRICT TREE CLEANUP & AUTO-PUBLISH
    # ==============================================================================
    if [ -f "${IMAGE_OUT_DIR}/img_2d.png" ]; then
        echo "[Clean Sync] Erasing historical tracking arrays to keep repository light..."
        
        # 1. Force clear the local git repository history tracking entirely
        rm -rf .git
        git gc --prune=now --aggressive 2>/dev/null

        # 2. Re-initialize a clean database layer
        git init
        git checkout -b "$BRANCH"
        git remote add origin "https://github.com/${githubUser}/${githubRepo}.git"

        # 3. Stage ONLY the specific components from your exact workspace layout
        git add ./swirls/img_2d.png
        git add swirls.sh
        
        if [ -f "./GHMWS.png" ]; then git add GHMWS.png; fi
        if [ -f "./index.html" ]; then git add index.html; fi

        # 4. Wrap everything into a single updated runtime commit tracking note
        git commit -m "Auto-update: $(date) [History Purged - Strict Tree Build]"

        # 5. Overwrite remote GitHub files and assign upstream pipeline tracking
        echo "[Engine Sync] Streaming clean workspace layer to GitHub..."
        if git push --set-upstream origin "$BRANCH" --force; then
            echo "✅ GitHub sync and branch auto-publishing complete!"
        else
            echo "❌ Force-push execution pipeline failure"
        fi
    else
        echo "⚠️ [Warning] Target radar imagery array missing. Skipping current Git execution frame."
    fi

    echo "等待 12 分鐘..."
    sleep 720
done