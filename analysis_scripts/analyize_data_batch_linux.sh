#!/bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color

while getopts ":d:u:p:s:a:l:v:c:m:f:t:r:g:" opt; do
  case ${opt} in
    d )
    dbname=$OPTARG
      ;;
    u )
    username=$OPTARG
      ;;
    p )
    password=$OPTARG
      ;;
    s )
    datasource=$OPTARG
      ;;     
    m )
    distance=$OPTARG
      ;;
    f )
    formula=$OPTARG
      ;;
    t )
    type=$OPTARG
      ;;
    r )
    resolution=$OPTARG
      ;;
    \? ) echo "Wrong parameter"
	 echo "Usage: cmd [-d database name] [-u database username] [-p database password] [-s path to folder containing input datasources] [-m analysis distance] [-f analysis formula] [-t analysis] type [-r raster output spatial resolution] [-g generalization tolerance]"  && exit
      ;;
  esac
done

##CHECK IF ALL PARAMETERS ARE SET
if [ ! "$dbname" ] || [ ! "$username" ] || [ ! "$password" ] || [ ! "$datasource" ] || [ ! "$distance" ] || [ ! "$formula" ] || [ ! "$type" ] || [ ! "$resolution" ]
then
    echo "Missing mandatory parameter"
    echo "Usage: cmd [-d database name] [-u database username] [-p database password] [-s path to folder containing input datasources] [-m analysis distance] [-f analysis formula] [-t analysis type] [-r raster output spatial resolution] [-g generalization tolerance]"  && exit
fi

#CHECK IF ANALYSIS DISTANCE, RASTER RESOLUTION AND GENERALIZATION TOLERANCE ARE INTEGERS
if ! [[ "$distance" =~ ^[0-9]+$ ]] || ! [[ "$resolution" =~ ^[0-9]+$ ]]
    then
        echo "Distance and resolution parameters can only be integer values" && exit
fi

if [[ -n "$generalization_tolerance" ]] && ! [[ "$generalization_tolerance" =~ ^[0-9]+$ ]]
    then
        echo "The generalization tolerance can only be an integer value" && exit
fi

if [[ -n "$generalization_tolerance" ]] && [[ "$type" != "ge" ]]
    then
        echo "Generalization tolerance provided but the analysis type does not match, so this value is ignored"
fi

#CHECK IF FORMULA AND TYPE PARAMETERS ARE AS EXPECTED
if ! [[ "$formula" == "li" ]] && ! [[ "$formula" == "ga" ]]
    then
        echo "Accepted values for the 'formula' paramters are 'li' or 'ga'" && exit
fi

if ! [[ "$type" == "bo" ]] && ! [[ "$type" == "bb" ]] && ! [[ "$type" == "ge" ]]
    then
        echo "Accepted values for the 'type' paramters are 'bo', 'bb' or 'ge'" && exit
fi

if [[ "$type" == "ge" ]] && [[ -z "$generalization_tolerance" ]]
    then
        echo "'generalization' chosen for the analysis, but tolerance not provided" && exit
fi


##CHECK IF THE PATH TO INPUTS EXIST
if [ ! -d $datasource ]; then
    echo "Input path NOT found!" && exit
else
nopath=$(basename -- "$datasource")
path=$(dirname "${datasource}")
fullpath=$(readlink -f $datasource)
fi

##CHECK IF IS POSSIBLE TO ESTABLISH A CONNECTION TO THE DATABASE AND IF IT HAS POSTGIS IN IT
message=$(PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "SELECT * FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';" 2>&1 >/dev/null)

if [[ $message == *"FATAL"* ]]; then
  echo "PostgreSQL username and/or password and/or database name are wrong" && exit
fi

message=$(PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "SELECT * FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';" | grep spatial)

if [[ $message != *"spatial_ref_sys"* ]]; then
  echo "The chosen PostgreSQL database does not have the PostGIS extension installed" && exit
fi

FILES=$fullpath/*.gpkg
for datasource in $FILES
do
nopath_ds=$(basename -- "$datasource")
path_ds=$(dirname "$datasource")
noext_ds="${nopath_ds%.*}"
fullpath_ds=$(readlink -f $datasource)

##SET THE NAME FOR A SCHEMA IN THE DATABASE THAT WILL HOLD THE INPUT DATA AND THE RESULTS
schemaname=$noext_ds"_"$formula"_"$type"_"$distance"_"$(date +'%m_%d_%Y_%H_%M')

##CREATE THE SCHEMA FOR THE RESULTS
check_schema=$(PGPASSWORD=$password psql -q -U $username -d $dbname -h localhost -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '$schemaname';")
if [[ $check_schema == *"1 row"* ]]; then
  sleep 1m
  schemaname=$noext_ds"_"$formula"_"$type"_"$distance"_"$(date +'%m_%d_%Y_%H_%M')
  PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE SCHEMA $schemaname;"
else
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE SCHEMA $schemaname;"
fi

echo ""
echo -e "Starting Process for datasource ${RED}$nopath_ds${NC}!"
echo -e "Analysis Data and Time: ${RED}$(date +'%m/%d/%Y %H:%M')${NC}"
echo -e "Analysis name: ${RED}$schemaname${NC}"

##CHECK IF THE PROVIDED DATASOURCE CONTAINS THE INPUT LAYERS AND IF THEY ARE THE PROPER TYPE AND HAVE THE PROPER CRS
##AND IF THE CLASS/VALUES COLUMNS EXIST AND ARE THE PROPER TYPE
check_sa="$(ogrinfo -so $datasource study_area | grep study_area)"
if [ "$check_sa" == "FAILURE: Couldn't fetch requested layer study_area!" ]
then
      echo "The datasurce does not contain a layer called 'study_area'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue
fi

check_sa_geom="$(ogrinfo -so $datasource study_area | grep 'Geometry:')"
if ([ -z "$check_sa_geom" ]) || ([ "$check_sa_geom" != "Geometry: Polygon" ] && [ "$check_sa_geom" != "Geometry: Multi Polygon" ])
then
      echo "The 'study_area' layer is not of type POLYGON or MULTIPOLYGON"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue      
fi

check_sa_proj="$(ogrinfo -so $datasource study_area | grep PROJCS)"
if [ -z "$check_sa_proj" ]
then
      echo "The layer called 'study_area' is NOT in a PROJECTED coordinate reference system"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue         
fi

check_sa="$(ogrinfo -so $datasource land_use | grep land_use)"
if [ "$check_sa" == "FAILURE: Couldn't fetch requested layer land_use!" ]
then
      echo "The datasurce does not contain a layer called 'land_use'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue
fi

check_sa_geom="$(ogrinfo -so $datasource land_use | grep 'Geometry:')"
if ([ -z "$check_sa_geom" ]) || ([ "$check_sa_geom" != "Geometry: Polygon" ] && [ "$check_sa_geom" != "Geometry: Multi Polygon" ])
then
      echo "The 'land_use' layer is not of type POLYGON or MULTIPOLYGON"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue      
fi

check_sa_proj="$(ogrinfo -so $datasource land_use | grep PROJCS)"
if [ -z "$check_sa_proj" ]
then
      echo "The layer called 'land_use' is NOT in a PROJECTED coordinate reference system"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue         
fi

check_sa_proj_code="$(ogrinfo -so $datasource study_area | grep 'AUTHORITY' | tail -1)"
check_lu_proj_code="$(ogrinfo -so $datasource land_use | grep 'AUTHORITY' | tail -1)"
if [ "$check_sa_proj_code=" != "$check_lu_proj_code=" ]
then
      echo "The study area and land use CRSs do not match"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue        
fi

check_class_col="$(ogrinfo -so $datasource land_use | grep -w "class")"
if [ -z "$check_class_col" ]
then
      echo "A column called 'class' is not present in the layer called 'land_use'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue      
fi

check_value_col="$(ogrinfo -so $datasource land_use | grep -w "value")"
if [ -z "$check_value_col" ]
then
      echo "A column called 'value' is not present in the layer called 'land_use'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue        
fi

check_type_col="$(ogrinfo -so $datasource land_use | grep -w "type")"
if [ -z "$check_type_col" ]
then
      echo "A column called 'type' is not present in the layer called 'land_use'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue        
fi

if [[ $check_value_col == *"String"* ]] || [[ $check_value_col == *"Date"* ]]
then
      echo "The column 'value' has a wrong datatype, must be DECIMAL or INTEGER"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue        
fi

check_type_column_value="$(ogrinfo -al $datasource -dialect SQLITE -sql 'SELECT DISTINCT type FROM land_use' | grep -w '(String) = source')"
if [ -z "$check_type_column_value" ]
then
      echo "In the column called 'type' there are no patches classified as 'source'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue 
fi

check_type_column_value="$(ogrinfo -al $datasource -dialect SQLITE -sql 'SELECT DISTINCT type FROM land_use' | grep -w '(String) = target')"
if [ -z "$check_type_column_value" ]
then
      echo "In the column called 'type' there are no patches classified as 'target'"
      echo "Skipping $datasource"
      PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "DROP SCHEMA $schemaname;"
      continue 
fi

crs="$(ogrinfo -so $datasource land_use | grep -w 'AUTHORITY' | tail -1 | grep -o -E '[0-9]+')"
sa_extent="$(ogrinfo -so $datasource study_area| grep -w 'Extent:' | sed 's/) - (/ /g' | sed 's/,//g' | sed 's/(//g' | sed 's/)//g' | sed 's/Extent: //g')"

##PICK THE NAME OF THE GEOMETRY COLUMN IN THE INPUT DATASOURCE AS WE CANNOT ASSUME IS "GEOM"
##lu_geom_name="$(ogrinfo -so $datasource land_use | grep -w 'Geometry Column =' | sed 's/Geometry Column = //g')"
sa_geom_name="$(ogrinfo -so $datasource land_use | grep -w 'Geometry Column =' | sed 's/Geometry Column = //g')"

#CHECK GDAL VERSION, AS SOME PARAMETERS MAY HAVE CHANGED NAME IN VERY RECENT RELEASES
gdalversion="$(ogrinfo --version | cut -f1 -d"," | sed 's/[^0-9]*//g')"
if (( $gdalversion > 240 ))
then
spatialindex='GIST'
else
spatialindex='YES'
fi

#IMPORT THE STUDY AREA AND LAND USE LAYERS
echo "Importing study area map..."
ogr2ogr -q -progress --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=$spatialindex -lco GEOMETRY_NAME=geom -lco FID=gid -nln $schemaname.study_area -nlt MULTIPOLYGON $datasource study_area -overwrite -lco OVERWRITE=YES -t_srs EPSG:$crs

echo "Buffering the study area map..."
ogr2ogr -q --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=$spatialindex -lco GEOMETRY_NAME=geom -lco FID=gid -nln $schemaname.study_area_buffered -nlt MULTIPOLYGON $datasource -dialect SQLITE -sql "SELECT 1 AS fid, ST_Union(ST_Buffer($sa_geom_name,2*$distance)) AS geom FROM study_area" -overwrite -lco OVERWRITE=YES -t_srs EPSG:$crs

#CHECK THE EXTENT OF THE BUFFERED STUDY AREA LAYER
sa_buffered_extent="$(ogrinfo -so "PG:host=localhost user=$username dbname=$dbname password=$password" $schemaname.study_area_buffered | grep -w 'Extent:' | sed 's/) - (/ /g' | sed 's/,//g'| sed 's/(//g'| sed 's/)//g'| sed 's/Extent: //g')"

echo "Importing land use map..."
ogr2ogr -q -progress --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=$spatialindex -lco GEOMETRY_NAME=geom -lco FID=gid -nln $schemaname.land_use_original -nlt MULTIPOLYGON $datasource land_use -overwrite -lco OVERWRITE=YES -t_srs EPSG:$crs

echo "Cleaning the land use map geometries..."
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "UPDATE $schemaname.land_use_original SET geom=ST_MakeValid(geom) WHERE ST_IsValid(geom) IS FALSE;" &>/dev/null

echo "Clipping the land use map with the buffered study area map extent..."
ogr2ogr -q --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=$spatialindex -lco GEOMETRY_NAME=geom -lco FID=gid -nln $schemaname.land_use_extent -nlt MULTIPOLYGON "PG:host=localhost user=$username dbname=$dbname password=$password" $schemaname.land_use_original -overwrite -lco OVERWRITE=YES -t_srs EPSG:$crs -spat $sa_buffered_extent -clipsrc spat_extent

echo "Clipping the land use map with the buffered study area map..."
ogr2ogr -q --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=$spatialindex -lco GEOMETRY_NAME=geom -lco FID=gid -nln $schemaname.land_use_clipped -nlt MULTIPOLYGON "PG:host=localhost user=$username dbname=$dbname password=$password" $schemaname.land_use_extent -clipsrc "PG:host=localhost user=$username dbname=$dbname password=$password" -clipsrclayer $schemaname.study_area_buffered -overwrite -lco OVERWRITE=YES -t_srs EPSG:$crs

echo -e "Creating the 'source' and 'target' patches layers..."
#CREATE THE SOURCE PATCHES LAYER
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.source_patches AS \
SELECT a.*, ST_Multi(ST_MakeValid(a.geom))::geometry('MULTIPOLYGON', $crs) AS geom_valid, ST_Multi(ST_Envelope(a.geom))::geometry('MULTIPOLYGON', $crs) AS bbox \
FROM $schemaname.land_use_clipped a \
WHERE a.type = 'source';"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.source_patches ADD PRIMARY KEY (gid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_geom_valid_idx ON $schemaname.source_patches USING gist (geom_valid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_bbox_idx ON $schemaname.source_patches USING gist (bbox);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_geom_idx ON $schemaname.source_patches USING gist (geom);"

if [[ "$type" == "ge" ]]
    then
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.source_patches ADD COLUMN geom_generalized geometry(MULTIPOLYGON,$crs);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "UPDATE $schemaname.source_patches SET geom_generalized = ST_Multi(ST_SimplifyPreserveTopology(geom,$generalization_tolerance));"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_geom_generalized_idx ON $schemaname.source_patches USING gist (geom_generalized);"
fi

#CREATE THE TARGET PATCHES LAYER
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.target_patches AS \
SELECT a.*, ST_Multi(ST_MakeValid(a.geom))::geometry('MULTIPOLYGON', $crs) AS geom_valid, ST_Multi(ST_Envelope(a.geom))::geometry('MULTIPOLYGON', $crs) AS bbox \
FROM $schemaname.land_use_clipped a \
WHERE a.type = 'target';"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.target_patches ADD PRIMARY KEY (gid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_geom_valid_idx ON $schemaname.target_patches USING gist (geom_valid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_bbox_idx ON $schemaname.target_patches USING gist (bbox);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_geom_idx ON $schemaname.target_patches USING gist (geom);"

if [[ "$type" == "ge" ]]
    then
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.target_patches ADD COLUMN geom_generalized geometry(MULTIPOLYGON,$crs);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "UPDATE $schemaname.target_patches SET geom_generalized = ST_Multi(ST_SimplifyPreserveTopology(geom,$generalization_tolerance));"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_geom_generalized_idx ON $schemaname.target_patches USING gist (geom_generalized);"
fi

echo -e "Processing the data within the database..."
##SET THE GEOMETRIES NAMES
if [ $type = "bb" ]
then
geom='bbox'
elif [ $type = "bo" ]
then
geom='geom_valid'
elif [ $type = "ge" ]
then
geom='geom_generalized'
fi

#SET THE FORUMLAS
if [ $formula = "li" ]
then
query='CASE WHEN ST_Distance(target_patches.'"$geom"', source_patches.'"$geom"')=0 THEN source_patches.value ELSE (1-(ST_Distance(target_patches.'"$geom"',source_patches.'"$geom"')/'"$distance"'))*source_patches.value END AS value_target, '
elif [ $formula = "ga" ]
then
query='source_patches.value*((2.718281828459045235360287471352662497757247093699959574966^(((ST_Distance(target_patches.'"$geom"',source_patches.'"$geom"')/'"$distance"')*(ST_Distance(target_patches.'"$geom"',source_patches.'"$geom"')/'"$distance"')*-4)+0.92))/sqrt(6.283185307179586476925286766559005768394338798750211641949)) AS value_target, '
fi

#RUN THE ANALYSIS   
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.raw_data AS \
SELECT \
   row_number() OVER () AS gid, \
   source_patches.gid AS id_source, \
   source_patches.class AS class_source, \
   target_patches.gid AS id_target, \
   target_patches.class AS class_target, \
   $query
   ST_Distance(target_patches.$geom, source_patches.$geom) AS distance, \
   ST_ShortestLine(target_patches.$geom, source_patches.$geom)::geometry('LINESTRING', $crs) AS geom, \
   source_patches.geom AS geom_source, target_patches.geom AS geom_target, \
   (source_patches.bbox)::geometry('MULTIPOLYGON', $crs) AS bbox_source, (target_patches.bbox)::geometry('MULTIPOLYGON', $crs) AS bbox_target \
 FROM \
   (SELECT DISTINCT ON (geom) * 
    FROM $schemaname.source_patches) AS source_patches \
 CROSS JOIN LATERAL \
   (SELECT * \
    FROM $schemaname.target_patches \
    ) AS target_patches \
    WHERE ST_Distance(target_patches.$geom, source_patches.$geom) < $distance \
         ORDER BY distance;"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.raw_data ADD PRIMARY KEY (gid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX rd_geom_idx ON $schemaname.raw_data USING gist (geom);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX rd_geom_source_idx ON $schemaname.raw_data USING gist (geom_source);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX rd_geom_target_idx ON $schemaname.raw_data USING gist (geom_target);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX rd_bbox_source_idx ON $schemaname.raw_data USING gist (bbox_source);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX rd_bbox_target_idx ON $schemaname.raw_data USING gist (bbox_target);"
         
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
        CREATE TABLE $schemaname.results AS \
        SELECT 
        row_number() OVER () AS gid, \
        id_target, class_target, \
        sum(value_target) AS value, \
        ST_Multi(ST_Union(geom_target))::geometry('MULTIPOLYGON', $crs) AS geom FROM 
        $schemaname.raw_data \
        GROUP BY id_target,class_target,geom_target;"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.results ADD PRIMARY KEY (gid);"     
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX re_geom_idx ON $schemaname.results USING gist (geom);"

#RASTERIZE RESULTS        
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.result_raster AS
select row_number() OVER () AS rid,
ST_asRaster(geom, $resolution. , -$resolution. , '32BF', value, -9999)
AS rast FROM $schemaname.results;"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.result_raster ADD PRIMARY KEY (rid);"

##EXPORT REUSULTS TO A GEOPACKAGE
echo -e "Exporting the results in Geopackage format..."
gdal_rasterize -q -l $schemaname.results -a value -tr $resolution $resolution -a_nodata -9999.0 -ot Float32 -of GTiff "PG:dbname=$dbname host=localhost port=5432 user=$username password=$password sslmode=disable" $path_ds/$schemaname'_results_rasterized'.tif
gdal_translate -q -of GPKG $path_ds/$schemaname'_results_rasterized'.tif $path_ds/$schemaname.gpkg -co RASTER_TABLE=results_rasterized
ogr2ogr -f GPKG $path_ds/$schemaname.gpkg "PG:dbname=$dbname host=localhost port=5432 user=$username password=$password sslmode=disable schemas=$schemaname" -update
rm $path_ds/$schemaname'_results_rasterized'.tif

echo -e "Analysis finished for ${RED}$nopath_ds${NC}"
output_abs_path="$(readlink -f $path_ds/$schemaname.gpkg)"
echo -e "Results saved in ${RED}$output_abs_path${NC}"

done
