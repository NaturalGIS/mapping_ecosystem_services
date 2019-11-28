# Mapping Biocontrol Ecosystem Services

**Reference:**

ALT20-03-0145-FEDER-000008

**Plugin concept by:**

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/uevora.png" width="300">

**Co-Funded by:**

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/grupodelogosfinanciamento-06.png" width="600">

**Developed by:**

<img src="https://github.com/NaturalGIS/naturalgis_ntv2_transformations/blob/master/icons/naturalgis.png">

web: http://www.naturalgis.pt/ 

email: info@naturalgis.pt

main developer: Luís Calisto

**Description:**

The "*Mapping Biocontrol Ecosystem Services*" QGIS plugin was developed by the University of Évora (Portugal) to map the biocontrol services that species occuring in natural and semi-natural habitats provide to agricultural areas. It calculates the overall biocontrol services provided by the natural habitat patches within a determined distance from the agricultural area. The biocontrol services provided can be distance weighted according to a linear decay function or a half-normal decay function.

**What it does:**

This plugin aims to 

**Requirements:**

The plugin needs QGIS >= 3.4 to work.

**Data preparation and known limitations:**

1) The plugin **needs** two different **polygon** layers as inputs:

    a) one representing the study/analysis area/s

    b) one representing a land use map

2) This two layers **must** have the same CRS (coordinate reference system) and the CRS **must** be a projected one (geographic CRSs are not supported).

3) Input layers features/geometries **must** be free of geometry errors, if in doubt clean them with QGIS's "**fix geometries**" tool **before** using them in this plugin.

4) The land use map/layers **must** have an attribute/column that represent the land/parcels classification. This attribute can be numeric (integer or decimal) or text.

5) The plugin needs to do a **distance analyasis**  that is known to be a slow type of analysis in GIS. Depending on the number of parcels involved in the analysis, the plugin can take quite a lot of time to compute the results, so **be patient**. The plugin allows to do the analysis using the parcels centroids rather than the parcels boundaries, if you want faster computation times use the centroids strategy.

**Instructions:**

The "Mapping Biocontrol Ecosystem Services" plugin can be installed (and updated) using QGIS's "Plugins Manager" ("Plugins" menu):

```Plugins >> Manage and Install Plugins```

After the installation the plugin will be available in QGIS's "Plugins" menu and "Plugins" toolbar.

The GUI looks like the following image:

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/gui.png" width="600">

1) "**Analysis distance (CRS units)**": is the maximum distance value that will be used to compute the influence between two parcels. Must be a value in meters (feet not tested).

2) "**Study area/s**": is the polygon layer (mandatory) containing the areas where the analysis will be run. Only the parcels that are fully within or crossing the study area/s polygons will be taken into account.

3) "**Land use areas (must be in the same CRS of study area/s layer)**": is the polygon (mandatory) layer containing the land use parcels. The CRS os this layer **must** match the one of the study area/s.

4) "**Land use classification attribute**": is the column of the *Land use areas (must be in the same CRS of study area/s layer)* that holds the land use classification. 

5) "**Formula**": the plugin supports two modes of computing the results. ***Linear*** uses the following formula:

```computed_value=(1-(computed_distance/analysis_distance))*source_value```

while ***gaussian*** uses the following:

```computed_value=source_value*((2,72^(((computed_distance/analysis_distance)(computed_distance/analysis_distance)-4)+0,92))/SQRT(6,3))```

6) "**Output folder**": the plugin outputs several layers/tables to a user specified folder:

    a) a Geopackage (GPKG) datasource/file containing the following vector layers/maps:

    - a copy of the study area/s layer/map

    - a copy of the land use layer/map containing only the land use parcels belonging to the land use classes that have been chosen to be part of the analysis

    - a **line** layer/map with the segments representing the min distance between parcels boundaries/centroids. In case uf using the "boundaries" strategy this layer **do not** contain the "zero length" lines representing the distance (equel to 0) of adjecent parcels.

    - a **raw_data** alphanumeric table containing all the distances and values computed between each parcel pair
    
    - a **polygon** layer/map containing a vector layer/map of the computed final results

    b) a raster layer/map of the computed final results
   
7) "**Output raster spatial resolution (CRS units)**": the spatial resolution (pixels size) of the raster output layer/map

8) "**Land use classes**": is the list of (unique) land use classes automatically populated after chosing the **Land use classification attribute**

9) "**Target land use classes**": user populated (by drag and drop from the **Land use classes** list) list of land use classes representing parcels of semi-natural habitat

10) "**Source land use classes and values**": user populated (by drag and drop from the **Land use classes** list) list of land use classes representing parcels of natural habitat. To each class in this list a **value** must be defined (interger or decimal number)

**Sample project/data:**

https://mapserver.uevora.pt/~mapserver/sample_project_and_data.zip

**References:**

This plugin was developed within the University of Évora (Portugal) within the project "*New tools for monitoring ecosystems services in traditional Alentejo production systems under intensification*" (ALT20-03-0145-FEDER-000008), co-funded by Alentejo 2020, Portugal 2020 and European Fund for Regional Development.
