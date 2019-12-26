# Mapping Biocontrol Ecosystem Services

ALT20-03-0145-FEDER-000008

**Plugin concept by:** J. Tiago Marques; Nuno Faria; Rui Lourenço; Amália Oliveira; Pedro F. Pereira; Joana Silva; Diogo Figueiredo; Teresa Pinto-Correia; João E. Rabaça; António Mira

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/uevora.png" width="300">

**Contact:** jtiagom@uevora.pt

**Co-Funded by:**

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/grupodelogosfinanciamento-06.png" width="600">

**Developed by:**

<img src="https://github.com/NaturalGIS/naturalgis_ntv2_transformations/blob/master/icons/naturalgis.png">

web: http://www.naturalgis.pt/ 

email: info@naturalgis.pt

QGIS plugin main developer: Luís Calisto (NaturalGIS)

Scripts main developer: Giovanni Manghi (NaturalGIS)

## Description

"*Mapping Biocontrol Ecosystem Services*" are a QGIS plugin and set of scripts that were conceived by J. Tiago Marques; Nuno Faria; Rui Lourenço; Amália Oliveira; Pedro F. Pereira; Joana Silva; João E. Rabaça; Teresa Pinto-Correia; Diogo Figueiredo; António Mira at the University of Évora (Portugal) to map the biocontrol services that species occuring in natural and semi-natural habitats provide to agricultural areas. It calculates the overall biocontrol services provided by the natural habitat patches within a determined distance from the agricultural area. The biocontrol services provided can be distance weighted by a linear or a half-normal decay function.

## Goal

This QGIS plugin and the scripts aim to compute the value that natural habitats and semi-natural land use patches provide to neighbouring agricultural areas (the distance is user defined).

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/analysis.png">

Example from the above image:

3.1 and 3.2 are classes of patches with a natural land use. 2.4 is a class of patches with agricultural land use.

Patch with id 1029 (class 3.1) contributes to patches with id 809 and 818 (class 2.4).

Patch with id 1117 (class 3.2) contributes to patches with id 809 and 818 (class 2.4).

Patch with id 1124 (class 3.2) contributes to patches with id 809 and 818 (class 2.4).

None of the patches with classes 3.1/3.2 contributes in value to the patches with id 839 (class 2.4) because the latter is farther than the analysis distance.

## Requirements and considerations

The **QGIS plugin** needs QGIS >= 3.4 to work, it is written in Python and does not need any particular Python library other than the ones installed by default with any QGIS installation. The plugin is multi-platform and is expected to work on GNU/Linux, macOS and MS Windows.

The **scripts** are meant to be run in a GNU/Linux (Bash) terminal. They were developed/written and tested on Ubuntu 18.04 so any other Linux distribution derived from it will work. If needed they can be easily modified to work on any other GNU/Linux distribution. Dependencies for the scripts are the [PostgreSQL](https://www.postgresql.org/) RDBMS, its [PostGIS](https://postgis.net/) spatial extension and the "gdal-bin" package (the latter is also a dependency of any QGIS installation). For security reasons only connections to a **local** PostgreSQL/PostGIS instance are supported: support for remote connections can be easily added if needed, but it probably means some kind of security isse. This scripts take advantage of the internal **geoprocessing** capabilities of a spatially enabled database like PostgreSQL/PostGIS.

Both the QGIS plugins and the scripts use a Spatial SQL approach to solve the problem they are tasked to. 

The scripts are faster than the QGIS plugin so to analyze large amount of data is sugegsted to use them instead of the QGIS plugin. One of the scripts was created to allow automatically batches of input data sources.

## QGIS plugin: data preparation

1) The plugin **needs** two different **polygon** layers as inputs:

    a) one representing the study/analysis area/s

    b) one representing a land use map

2) This two layers **must** have the same CRS (coordinate reference system) and the CRS **must** be a projected one (geographic CRSs, with degrees as units, are not supported).

3) Input layers features/geometries **must** be free of geometry errors, if in doubt clean them with QGIS's "**fix geometries**" tool **before** using them in this plugin.

4) The land use map/layers **must** have an attribute/column that represent the patches classification. This attribute can be numeric (integer or decimal) or text.

5) As part of the computations the  plugin does a **distance analysis**, a type if GIS analysis that is known to be slow when large amount of data is being processed. Depending on the number of patches involved in the analysis the plugin can take quite a long time to compute the results so **please be patient** (in this cases consider using the scripts instead). The plugin allows to do the analysis using the patches **bounding boxes** rather than the patches **boundaries**, if you want faster computation times (at the cost of a slighty less precise analysis) use the "**Bounding boxes**" option.

## QGIS plugin installation and usage

The "Mapping Biocontrol Ecosystem Services" QGIS plugin can be installed (and updated) using QGIS's "Plugins Manager" ("Plugins" menu):

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
   
8) "**Output raster spatial resolution (CRS units)**": the spatial resolution (pixels size) of the raster output layer/map. The resolution must be high enough (small enough numeric value) for the rasterization process be able to generate the clusters representing very small parcels.

9) "**Land use classes**": the list of (unique) land use classes automatically populated after choosing the **Land use classification attribute**.

10) "**Target land use classes**": user populated (by drag and drop from the **Land use classes** list) list of land use classes representing patches of agricultural habitats.

11) "**Source land use classes and values**": user populated (by drag and drop from the **Land use classes** list) list of land use classes representing patches of natural or semi-natural habitat. To each class on this list a **value** must be defined (interger or decimal number). For example the average species richness of bats or insectivorous birds.

## Scripts description and usage

### Description

The scripts are found here https://github.com/NaturalGIS/mapping_ecosystem_services/tree/master/analysis_script and are distributed along with the QGIS plugin but they can be downloaded and used in a completely independet way.

### For GNU/Linux

**init_postgis_database_linux.sh**: this script is meant to install and configure all the needed dependencies on a Ubuntu 18.04 (or derivate GNU/Linux distribution) machine: 

* PostgreSQL/PostGIS

* gdal-bin

The script also allows to create a database and a database user that can be used for the analysis of the data. Running this script is not mandatory if the computer being used has already a PostgreSQL/PostGIS installation and a database/database user (with write permissions) are already available to be used.

**analyize_data_linux.sh**: this the script used to analyze one specific set of input data. The results are outputted as layers/tables inside the database and also as a Geopackage (GPKG) datasource.

**analyize_data_batch_linux.sh**: it is a version of "analyize_data_linux.sh" made to process automatically multiple sets of iput data, typically a folder with > 1 Geopckage (GPKG) dataource in it.

### Data preparation

The input data must be prepared in a very precise way. This can be easily done within Desktop GIS applications like QGIS. The scripts where tested using [GPKGs datasources](https://www.geopackage.org/) but is possible that other multi-layered datasources (i.e. Spatialite, ESRI file geodatabase, etc.) can work.

The input map/layers must exist within a **single** Geopackage (GPKG) datasource (this file can be named in any way):

- a (MULTI)POLYGON map/layer representing the study/analysis area. When using the **analyize_data_batch_linux.sh** script this layer **MUST** be named "**study_area**". The attributes for this layer are not important.

- a (MULTI)POLYGON map/layer representing the land use. When using the **analyize_data_batch_linux.sh** script this layer **MUST** be named "**land_use**". 

The land use map/layer **MUST** have a few **mandatory** attributes/columns

- a column (can be text or numeric) that will hold the land use classification. When using the **analyize_data_batch_linux.sh** script this column **MUST** be named  **class**
    
- a column (can be inetger or decimal) that will hold the value associated with the land use classification. When using the **analyize_data_batch_linux.sh** script this column **MUST** be named  **value**

- a column that must be named **type** (must be text): this column must contain the words "**target**" or "**source**" associated with the parcels that are meant to be used as "target" and "source" in the analysis

<img src="https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/img/data_example.png" width="600">

In the above image and example of a table of attributes for a "land use" input map/layer, with patches belonging to the "source" type (together with their associated values", patches belonging to the "target" type and parcels that will not enter the analysis.

#### Usage

- Step1: After downloading the scripts make them executable

    ```chmod +x *.sh```

- Step2 (optional): install scripts dependencies and initialize/create a necessary database and database user

    ```sudo ./init_postgis_database_linux.sh```
    
    This script will do in order:
    
    - refresh the repositories lists
    
    - install updates for the operating system
    
    - install PostgreSQL, PostGIS and the gdal-bin package
    
    - ask to choose a name for a database that will be created
    
    - ask to choose a (database) username that will be the owner of the database created in the previous step
    
    - ask to choose a password for the database user created in the previous step
    
    - add the PostGIS extension to the database created in the previous steps
    
    - set the proper permissions on the "geometry_columns" table within the database created in the previous steps

- Step3: run the analysis, single datasource mode (**analyize_data_linux.sh**). The general usage for this script is:

    ```./analyize_data_linux.sh [-d database name] [-u database username] [-p database password] [-s path to multilayer datasource] [-a study area layer name] [-l land use layer name] [-v land use value] [-c land use class] [-m analysis distance] [-f analysis formula] [-t] analysis type [-r raster output spatial resolution]```
    
    Example:

    ```./analyize_data_linux.sh -d db_name -u db_username -p db_password -s test/sample_data.gpkg -a study_area -l land_use -v value -c class -m 10000 -f ga -t bo -r 10```

    that would produce an output like:

    ```Starting Process!
    Analysis Data and Time: 12/26/2019 18:29
    Analysis name: sample_data_ga_bo_22001_12_26_2019_18_29

    Importing study area map...
    Importing land use map...
    Processing the data within the database...
    Exporting the results in Geopackage format...

    Analysis finished
    Results saved in /home/land_analysis/test/sample_data_ga_bo_22001_12_26_2019_18_29.gpkg
    ```
    
    Parameters explanation:

    **-d db_name** > name of the database to be used to run the analysis and store the results

    **-u db_username** > database username, must be owner of the database chosen with the "-d" parameter

    **-p db_password** > password of the database user

    **-s test/sample_data.gpkg** > path (absolute or relative) that points to the datasource with the input layers

    **-a study_area** > name of the "study area" map/layer

    **-l land_use**> name of the "land use" map/layer

    **-v value** > name of the column in the "land use" map/layer that holds the values for the "source" patches

    **-c class** > name of the column in the "land use" map/layer that holds the classificstion of the patches

    **-m 10000** > analysis max distance (in meters)

    **-f ga** > formula to be used, can be "ga" (gaussian) or "li" (linear)

    **-t bo** > type pf the analysis, can be "bo" (boundaries) or "bb" (bounding boxes"

    **-r 10** > resolution (in meters) of the raster output

- Step4 (optional): run the analysis, multiple datasource mode (**analyize_data_batch_linux.sh**). The general usage for this script is:

    ```./analyize_data_batch_linux.sh [-d database name] [-u database username] [-p database password] [-s path to folder containing input datasources] [-m analysis distance] [-f analysis formula] [-t] analysis type [-r raster output spatial resolution]```

    Example:

    ```./analyize_data_batch_linux.sh -d db_name -u db_username -p db_password -s test/ -m 3000 -f ga -t bo -r 50```
    
    that would produce an output like:
    
    ```Starting Process for datasource sample_data2.gpkg!
    Analysis Data and Time: 12/26/2019 18:49
    Analysis name: sample_data2_ga_bo_22000_12_26_2019_18_49
    Importing study area map...
    Importing land use map...
    Processing the data within the database...
    Exporting the results in Geopackage format...
    Analysis finished for sample_data2.gpkg
    Results saved in /home/land_analysis/test/sample_data2_ga_bo_22000_12_26_2019_18_49.gpkg

    Starting Process for datasource sample_data3.gpkg!
    Analysis Data and Time: 12/26/2019 18:49
    Analysis name: sample_data3_ga_bo_22000_12_26_2019_18_49
    The column 'value' has a wrong datatype, must be DECIMAL or INTEGER
    Skipping /home/land_analysis/test/sample_data3.gpkg

    Starting Process for datasource sample_data.gpkg!
    Analysis Data and Time: 12/26/2019 18:49
    Analysis name: sample_data_ga_bo_22000_12_26_2019_18_49
    Importing study area map...
    Importing land use map...
    Processing the data within the database...
    Exporting the results in Geopackage format...
    Analysis finished for sample_data.gpkg
    Results saved in /home/land_analysis/test/sample_data_ga_bo_22000_12_26_2019_18_49.gpkg
    ```
    
     Parameters explanation:

     The parameters are the same as the "single mode" script, but there are a few missing ones as is expected for a few             variables to have specific values (see above).

### For MS Windows

Recent versions of MS Windows 10 have the hability to run natively GNU/Linux programs/scripts using the
[Windows Subsystem for Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux)
, for this reason a MS Windows specific version of the scripts will not be created, instead just use the WSL and the GNU/Linux version of the scripts, see:

https://docs.microsoft.com/en-us/windows/wsl/install-win10

https://docs.microsoft.com/en-us/windows/wsl/initialize-distro

### macOS

A macOS version of the scripts is under consideration.

## Sample data

https://github.com/NaturalGIS/mapping_ecosystem_services/blob/master/analysis_scripts/sample_data.gpkg

## Funding

This plugin was developed at the University of Évora (Portugal) within the project "*New tools for monitoring ecosystems services in traditional Alentejo production systems under intensification*" (ALT20-03-0145-FEDER-000008), co-funded by Alentejo 2020, Portugal 2020 and European Fund for Regional Development.

## References

*Rega, C., Bartual, A. M., Bocci, G., Sutter, L., Albrecht, M., Moonen, A.-C., Jeanneret, P., van der Werf, W., Pfister, S. C., Holland, J. M. and Paracchini, M. L. (2018). A pan-European model of 
landscape potential to support natural pest control services. Ecological Indicators, 90, 653-664.*
