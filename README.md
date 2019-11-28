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

**Short Description:**

The "*Mapping Biocontrol Ecosystem Services*" QGIS plugin was developed by the University of Évora (Portugal) to map the biocontrol services that species occuring in natural and semi-natural habitats provide to agricultural areas. It calculates the overall biocontrol services provided by the natural habitat patches within a determined distance from the agricultural area. The biocontrol services provided can be distance weighted according to a linear decay function or a half-normal decay function.

**Long Description:**

**Requirements:**

The plugin needs QGIS >= 3.4 to work.

**Data preparation and known limitations:**

1) The plugin **needs** two different **polygon** layers as inputs:

a) one representing the study/analysis area/s

b) one representing a land use map

2) This two layers **must** have the same CRS (coordinate reference system) and the CRS **must** be a projected one (geographic CRSs are not supported).

3) Input layers features/geometries **must** be free of geometry errors, if in doubt clean them with QGIS's "**fix geometries**" tool **before** using them in this plugin.

4) The land use map/layers **must** have an attribute/column that represent the land/parcels classification. This attribute can be numeric (integer or decimal) or text.

5) The plugin needs to do a **distance analyasis**  that is known to be a slow type of analysis in GIS. Depending on the number of parcels involved in the analysis, the plugin can take quite a lot of time to compute the results, so be patient. The plugin allows to do the analysis using the parcels centroids rather than the parcels boundaries, if you want faster computation times use the centroids strategy.

**Instructions:**

The "Mapping Biocontrol Ecosystem Services" can be installed (and updated) using QGIS's Plugins Manager ("Plugins" menu):

```Plugins >> Manage and Install Plugins```

After the installation the plugin will be available in QGIS's "Plugins" menu and the "Plugins" toolbar.

**Sample project/data:**

**References:**

This plugin was developed within the University of Évora (Portugal) within the project "*New tools for monitoring ecosystems services in traditional Alentejo production systems under intensification*" (ALT20-03-0145-FEDER-000008), co-funded by Alentejo 2020, Portugal 2020 and European Fund for Regional Development.
