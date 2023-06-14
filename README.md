# USCROPSOIL
This repository includes Matlab Scripts to tabulate crop information, soil information in lower 48 US states based on Cropland Data Layers (2008 and onwards) and gSSURGO maps. Each 30 meter cells from CDL will also have other spatial location information such as county, HUC8 and HUC12 information based on the center of the CDL cells.

# Summary
This repository is an extension of https://github.com/haipai/CDL2gssurgo which is based on state Cropland Data Layers. Due to the large size of both National CDL layers and gSSURGO maps, there will be only MATLAB scripts here. Interested users can download the necessary data files. 

# Data Downloading 
1. National CDL (https://www.nass.usda.gov/Research_and_Science/Cropland/Release/index.php) 
2. gSSURGO database (https://www.nrcs.usda.gov/resources/data-and-reports/gridded-soil-survey-geographic-gssurgo-database). version: gSSURGO_CONUS_202210.gdb.zip
3. County shape file (https://www2.census.gov/geo/tiger/GENZ2022/shp/?C=S;O=D) version: cb_2022_us_county_500k.zip
4. Water Boundary Database (https://www.usgs.gov/national-hydrography/access-national-hydrography-products) version: 
