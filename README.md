# Mapping Biocontrol Ecosystem Services

**Reference:**

ALT20-03-0145-FEDER-000008

**Plugin concept by:** J. Tiago Marques; Nuno Faria; Rui Lourenço; Amália Oliveira; Pedro F. Pereira; Joana Silva; Diogo Figueiredo; Teresa Pinto-Correia; João E. Rabaça; António Mira

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/uevora.png" width="300">

**Co-Funded by:**

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/grupodelogosfinanciamento-06.png" width="600">

**Developed by:**

<img src="https://github.com/NaturalGIS/naturalgis_ntv2_transformations/blob/master/icons/naturalgis.png">

web: http://www.naturalgis.pt/ 

email: info@naturalgis.pt

QGIS plugin main developer: Luís Calisto (NaturalGIS)

Bash scripts main developer: Giovanni Manghi (NaturalGIS)

## Description

"*Mapping Biocontrol Ecosystem Services*" are a QGIS plugin and set of scripts that were conceived by J. Tiago Marques; Nuno Faria; Rui Lourenço; Amália Oliveira; Pedro F. Pereira; Joana Silva; João E. Rabaça; Teresa Pinto-Correia; Diogo Figueiredo; António Mira at the University of Évora (Portugal) to map the biocontrol services that species occuring in natural and semi-natural habitats provide to agricultural areas. It calculates the overall biocontrol services provided by the natural habitat patches within a determined distance from the agricultural area. The biocontrol services provided can be distance weighted by a linear or a half-normal decay function.

## Goal

This QGIS plugin and the scripts aim to compute the value that natural habitats and semi-natural land use patches provide to neighbouring agricultural areas (the distance is user defined).

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/analysis.png">

Example from the above image:

3.1 and 3.2 are classes of patches with a natural land use. 2.4 is a class of patches with a agricultural land use.

Patch with id 1029 (class 3.1) contributes to patches with id 809 and 818 (class 2.4).

Patch with id 1117 (class 3.2) contributes to patches with id 809 and 818 (class 2.4).

Patch with id 1124 (class 3.2) contributes to patches with id 809 and 818 (class 2.4).

None of the patches with classes 3.1/3.2 contributes in value to the patches with id 839 (class 2.4) because the latter is farther than the analysis distance.

## Requirements and considerations

The **QGIS plugin** needs QGIS >= 3.4 to work. It is written in Python and does not need any particular library other than the ones installed by default by any QGIS installer. The plugin is multi-platform and is expected to work on GNU/Linux, macOS and MS Windows.

The **scripts** are meant to run from within a GNU/Linux terminal. They were developed and tested on Ubuntu 18.04 so any other Linux distribution based on Ubuntu 18.04 is likely to work but they can be easily modified to work on any other Linux distribution. A MS Windows version of the scripts is likely to be added in the next future while a macOS version is unlikley to ever happen. Dependencies for the scripts are the [PostgreSQL](https://www.postgresql.org/) RDBMS (with the [PostGIS](https://postgis.net/) spatial extension) and the "gdal-bin" package (the latter is also a dependency of any QGIS installation). For security reasons only connections to a **local** PostgreSQL/PostGIS instance are supported (support for remote connections can be easily added if needed).

Both the QGIS plugins and the scripts use a Spatial SQL approach to solve the problem thay are tasked to. 

The scripts are largerly faster than the QGIS plugin so, to analyze large amount of data, consider using them. Moreover one of the scripts allows to batch process data which allows to process automatically a lot of data.

## QGIS plugin: data preparation and known limitations:

1) The plugin **needs** two different **polygon** layers as inputs:

    a) one representing the study/analysis area/s

    b) one representing a land use map

2) This two layers **must** have the same CRS (coordinate reference system) and the CRS **must** be a projected one (geographic CRSs are not supported).

3) Input layers features/geometries **must** be free of geometry errors, if in doubt clean them with QGIS's "**fix geometries**" tool **before** using them in this plugin.

4) The land use map/layers **must** have an attribute/column that represent the patches classification. This attribute can be numeric (integer or decimal) or text.

5) The plugin needs to do a **distance analyasis**, a type if GIS analysis that is known to be a slow when large amount of data need to be processed. Depending on the number of patches  involved in the analysis, the plugin can take quite a long time to compute the results so **please be patient**. The plugin allows to do the analysis using the patches **bounding boxes** rather than the patches **boundaries**, if you want faster computation times (at the cost of a slighty less precise analysis) use the "**Bounding boxes**" option.

## QGIS plugin installation and usage

The "Mapping Biocontrol Ecosystem Services" QGUS plugin can be installed (and updated) using QGIS's "Plugins Manager" ("Plugins" menu):

```Plugins >> Manage and Install Plugins```

After the installation the plugin will be available in QGIS's "Plugins" menu and "Plugins" toolbar.

The GUI looks like the following image:

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/gui.png" width="600">

1) "**Analysis distance (CRS units)**": is the maximum distance value that will be used to compute the influence between two patches. Must be a value in map/CRS units (tested meters, feet not tested).

2) "**Study area/s**": is the polygon layer (mandatory) containing the areas where the analysis will be run. Only the patches that are fully within or crossing the study area/s polygons will be taken into account.

3) "**Land use areas (must be in the same CRS of study area/s layer)**": is the polygon (mandatory) layer containing the land use patches. The CRS of this layer **must** match the one of the study area/s.

4) "**Land use classification attribute**": is the column of the *Land use areas (must be in the same CRS of study area/s layer)* that holds the land use classification. 

5) "**Formula**": the plugin supports two modes of computing the results. ***Linear*** uses the following formula:

```computed_value=(1-(computed_distance/analysis_distance))*source_value```

while ***Gaussian*** uses the following:

```computed_value=source_value*((2,72^(((computed_distance/analysis_distance)(computed_distance/analysis_distance)-4)+0,92))/SQRT(6,3))```

6) "**Analysis strategy**": the plugin allows to choose between two strategies, "Bounding boxes" (faster, less precise) and "Boundaries" (slower, more precise).

7) "**Output folder**": the plugin outputs several layers/tables to a user specified folder:

    a) a Geopackage (GPKG) datasource/file containing the following vector layers/maps:

    - a copy of the study area/s layer/map

    - a copy of the land use layer/map containing only the land use patches belonging to the land use classes that have been chosen to be part of the analysis

    - a **line** layer/map with the segments representing the minimum distance between patches boundaries/centroids. This layer **does not** contain the "zero length" lines representing the distance (equal to 0) of adjacent patches (or of overlapping bounding boxes).

    - a **raw_data** alphanumeric table containing all the distances and values computed between each patch pair
    
    - a **polygon** layer/map containing a vector layer/map of the computed final results

    b) a raster layer/map of the computed final results
   
8) "**Output raster spatial resolution (CRS units)**": the spatial resolution (pixels size) of the raster output layer/map. The resolution must be high enough for the rasterization process be able to generate the clusters representing very small parcels.

9) "**Land use classes**": the list of (unique) land use classes automatically populated after choosing the **Land use classification attribute**.

10) "**Target land use classes**": user populated (by drag and drop from the **Land use classes** list) list of land use classes representing patches of agricultural habitats.

11) "**Source land use classes and values**": user populated (by drag and drop from the **Land use classes** list) list of land use classes representing patches of natural or semi-natural habitat. To each class in this list a **value** must be defined (interger or decimal number).

## Sample data

https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/analysis_scripts/sample_data.gpkg

## Funding

This plugin was developed at the University of Évora (Portugal) within the project "*New tools for monitoring ecosystems services in traditional Alentejo production systems under intensification*" (ALT20-03-0145-FEDER-000008), co-funded by Alentejo 2020, Portugal 2020 and European Fund for Regional Development.

## References

TO-DO
