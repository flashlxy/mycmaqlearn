
# landuse data process

1. you can visit https://e4ftl01.cr.usgs.gov/MOTA/ to obtain data

2. 此处需要用到“MODLAND Tile Calculator”工具，确定你所选定的区域位于那个投影分带块

   visit: https://landweb.modaps.eosdis.nasa.gov/cgi-bin/developer/tilemap.cgi
   
<a id=Table-1></a>
**Table 1. NLCD/MODIS output land cover classes from the
computeGridLandUse tool.**

|**Array Index**|**MODIS Class IGBP (Type 1)**|**Class Name**|**Array Index**|**NLCD Class**|**Class Name**|
|---|---|---|---|---|---|
|1|1|Evergreen Needleleaf forest|21| 11|Open Water
|2|2|Evergreen Broadleaf forest | 22 | 12  | Perennial Ice/Snow|
|3|3|Deciduous Needleleaf forest | 23 |           21|Developed - Open Space|
|4 |4 |Deciduous Broadleaf forest | 24 |22 |Developed - Low Intensity|
|5|5 | Mixed forest| 25|23|Developed - Medium Intensity|
|6|6|Closed shrublands| 26| 24| Developed High Intensity|
|7|7 |Open shrublands| 27|31|Barren Land (Rock/Sand/Clay)|
|8|8 |Woody savannas| 28|41|Deciduous Forest
|9|9|Savannas| 29|42|Evergreen Forest
|10|10| Grasslands| 30 |43| Mixed Forest|
|11|11|Permanent wetlands|31|51|Dwarf Scrub
|12|12| Croplands| 32|52|Shrub/Scrub|
|13|13 |Urban and built-up|33|71| Grassland/Herbaceous|
|14|14 |Cropland/Natural vegetation mosaic |  34|72 |Sedge/Herbaceous|
|15 |15|Snow and ice| 35|73|Lichens|
|16 |16|Barren or sparsely vegetated |        36|74|Moss|
|17 |0| Water | 37 |81|Pasture/Hay|
|18|18|Reserved (e.g., Unclassified)|  38| 82 |Cultivated Crops|
|19|19 |Reserved (e.g., Fill Value ) |  39 |90|Woody Wetlands|
|20|20| Reserved| 40 | 95|Emergent Herbaceous Wetlands|

3. use perl download and refer on 

http://blog.sina.com.cn/s/blog_71261a2d01016ma6.html

https://wiki.earthdata.nasa.gov/display/EL/How+To+Access+Data+With+Python

   
   
   a.perl -MCPAN -e shell
   
   b.install LWP::UserAgent
