#!/bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color

while getopts ":d:u:p:s:a:l:v:c:m:f:t:r:" opt; do
  case ${opt} in
    d )
    dbname=$OPTARG
    #echo $dbname
      ;;
    u )
    username=$OPTARG
    #echo $username
      ;;
    p )
    password=$OPTARG
    #echo $password
      ;;
    s )
    datasource=$OPTARG
    #echo $datasource
      ;;
    a )
    study_area_layer=$OPTARG
    #echo $study_area_layer
      ;;
    l )
    land_use_layer=$OPTARG
    #echo $land_use_layer
      ;;
    v )
    land_use_value=$OPTARG
    #echo $land_use_value
      ;;
    c )
    land_use_class=$OPTARG
    #echo $land_use_class
      ;;      
    m )
    distance=$OPTARG
    #echo $distance
      ;;
    f )
    formula=$OPTARG
    #echo $formula
      ;;
    t )
    type=$OPTARG
    #echo $type
      ;;
    r )
    resolution=$OPTARG
    #echo $resolution
      ;;
    \? ) echo "Wrong parameter"
	 echo "Usage: cmd [-d database name] [-u database username] [-p database password] [-s path to multilayer datasource] [-a study area layer name] [-l land use layer name] [-v land use value] [-c land use class] [-m analysis distance] [-f analysis formula] [-t] analysis type [-r raster output spatial resolution]"  && exit
      ;;
  esac
done

##CHECK IF ALL PARAMETERS ARE SET
if [ ! "$dbname" ] || [ ! "$username" ] || [ ! "$password" ] || [ ! "$datasource" ] || [ ! "$study_area_layer" ] || [ ! "$land_use_layer" ] || [ ! "$land_use_value" ] || [ ! "$land_use_class" ] || [ ! "$distance" ] || [ ! "$formula" ] || [ ! "$type" ] || [ ! "$resolution" ]
then
    echo "Missing mandatory parameter"
    echo "Usage: cmd [-d database name] [-u database username] [-p database password] [-s path to multilayer datasource] [-a study area layer name] [-l land use layer name] [-v land use value] [-c land use class] [-m analysis distance] [-f analysis formula] [-t] analysis type [-r raster output spatial resolution]"  && exit
fi

#CHECK IF ANALYSIS DISTANCE AND RASTER RESOLUTION ARE INTEGERS
if ! [[ "$distance" =~ ^[0-9]+$ ]] || ! [[ "$resolution" =~ ^[0-9]+$ ]]
    then
        echo "Distance and resolution parameters can only be integer values" && exit
fi

#CHECK IF FORMULA AND TYPE PARAMETERS ARE AS EXPECTED
if ! [[ "$formula" == "li" ]] && ! [[ "$formula" == "ga" ]]
    then
        echo "Accepted values for the 'formula' paramters are 'li' or 'ga'" && exit
fi

if ! [[ "$type" == "bo" ]] && ! [[ "$type" == "bb" ]]
    then
        echo "Accepted values for the 'type' paramters are 'bo' or 'bb'" && exit
fi

##CHECK IF THE GPKG DATASOURCE EXIST
if [ ! -f $datasource ]; then
    echo "Input Datasource NOT found!" && exit
else
nopath=$(basename -- "$datasource")
path=$(dirname "${datasource}")
noext="${nopath%.*}"
#echo $nopath
#echo $path
#echo $noext
fi

##CHECK IF THE PROVIDED DATASOURCE CONTAINS THE INPUT LAYERS AND IF THEY ARE THE PROPER TYPE AND HAVE THE PROPER CRS
##AND IF THE CLASS/VALUES COLUMNS EXIST AND ARE THE PROPER TYPE
check_sa="$(ogrinfo -so $datasource $study_area_layer | grep $study_area_layer)"
if [ "$check_sa" == "FAILURE: Couldn't fetch requested layer $study_area_layer!" ]
then
      echo "The datasurce does not contain a layer called '$study_area_layer'" && exit
fi

check_sa_geom="$(ogrinfo -so $datasource $study_area_layer | grep 'Geometry:')"
#echo $check_sa_geom
if ([ -z "$check_sa_geom" ]) || ([ "$check_sa_geom" != "Geometry: Polygon" ] && [ "$check_sa_geom" != "Geometry: Multi Polygon" ])
then
      echo "The '$study_area_layer' layer is not of type POLYGON or MULTIPOLYGON" && exit
fi

check_sa_proj="$(ogrinfo -so $datasource $study_area_layer | grep PROJCS)"
if [ -z "$check_sa_proj" ]
then
      echo "The layer called '$study_area_layer' is NOT in a PROJECTED coordinate reference system" && exit
fi

check_lu="$(ogrinfo -so $datasource $land_use_layer | grep $land_use_layer)"
if [ "$check_lu" == "FAILURE: Couldn't fetch requested layer $land_use_layer!" ]
then
      echo "The datasurce does not contain a layer called '$land_use_layer'" && exit
fi

check_lu_geom="$(ogrinfo -so $datasource $land_use_layer | grep 'Geometry:')"
#echo $check_sa_geom
if ([ -z "$check_lu_geom" ]) || ([ "$check_sa_geom" != "Geometry: Polygon" ] && [ "$check_sa_geom" != "Geometry: Multi Polygon" ])
then
      echo "The '$land_use_layer' layer is not of type POLYGON or MULTIPOLYGON" && exit
fi

check_lu_proj="$(ogrinfo -so $datasource $land_use_layer | grep PROJCS)"
if [ -z "$check_lu_proj" ]
then
      echo "The layer called '$land_use_layer' is NOT in a PROJECTED coordinate reference system" && exit
fi

check_sa_proj_code="$(ogrinfo -so $datasource $study_area_layer | grep 'AUTHORITY' | tail -1)"
check_lu_proj_code="$(ogrinfo -so $datasource $land_use_layer | grep 'AUTHORITY' | tail -1)"
if [ "$check_sa_proj_code=" != "$check_lu_proj_code=" ]
then
      echo "The study area and land use CRSs do not match" && exit
fi

check_class_col="$(ogrinfo -so $datasource $land_use_layer | grep -w "$land_use_class")"
if [ -z "$check_class_col" ]
then
      echo "A column called '$land_use_class' is not present in the layer called '$land_use_layer'" && exit
fi

check_value_col="$(ogrinfo -so $datasource $land_use_layer | grep -w "$land_use_value")"
if [ -z "$check_value_col" ]
then
      echo "A column called '$land_use_value' is not present in the layer called '$land_use_layer'" && exit
fi
if [[ $check_value_col == *"String"* ]] || [[ $check_value_col == *"Date"* ]]
then
      echo "The column '$land_use_value' has a wrong datatype, must be DECIMAL or INTEGER" && exit
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

##SET THE NAME FOR A SCHEMA IN THE DATABASE THAT WILL HOLD THE INPUT DATA AND THE RESULTS
schemaname=$noext"_"$formula"_"$type"_"$distance"_"$(date +'%m_%d_%Y_%H_%M')

##CREATE THE SCHEMA FOR THE RESULTS
check_schema=$(PGPASSWORD=land6 psql -q -U land6 -d land6 -h localhost -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '$schemaname';")
if [[ $check_schema == *"1 row"* ]]; then
  ##echo "Database schema name already exists, wait at least 1 minute before running the analysis" && exit
  sleep 1m
  schemaname=$noext"_"$formula"_"$type"_"$distance"_"$(date +'%m_%d_%Y_%H_%M')
  PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE SCHEMA $schemaname;"
else
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE SCHEMA $schemaname;"
fi

echo ""
echo -e "Starting Process!"
echo -e "Analysis Data and Time: ${RED}$(date +'%m/%d/%Y %H:%M')${NC}"
echo -e "Analysis name: ${RED}$schemaname${NC}"
echo ""

#IMPORT THE STUDY AREA AND LAND USE LAYERS
echo "Importing study area map..."
ogr2ogr -q -progress --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SCHEMA=$schemaname -lco GEOMETRY_NAME=geom -lco FID=gid -nln study_area -nlt MULTIPOLYGON $datasource $study_area_layer
echo "Importing land use map..."
ogr2ogr -q -progress --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SCHEMA=$schemaname -lco GEOMETRY_NAME=geom -lco FID=gid -nln land_use -nlt MULTIPOLYGON $datasource $land_use_layer

echo -e "Processing the data within the database..."
##CREATE THE SOURCE PARCELS LAYER
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.source_parcels AS \
SELECT a.*, ST_MakeValid(a.geom) AS geom_valid, ST_Envelope(a.geom) AS bbox \
FROM $schemaname.land_use a, $schemaname.study_area b \
WHERE a.type = 'source' AND ST_Intersects(a.geom,b.geom) IS TRUE;"

##CREATE THE TARGET PARCELS LAYER
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.target_parcels AS \
SELECT a.*, ST_MakeValid(a.geom) AS geom_valid, ST_Envelope(a.geom) AS bbox \
FROM $schemaname.land_use a, $schemaname.study_area b \
WHERE a.type = 'target' AND ST_Intersects(a.geom,b.geom) IS TRUE;"

##SET THE GEOMETRIES NAMES
if [ $type = "bb" ]
then
geom='bbox'
elif [ $type = "bo" ]
then
geom='geom_valid'
fi

##SET THE FORUMLAS
if [ $formula = "li" ]
then
query='CASE WHEN ST_Distance(target_parcels.'"$geom"', source_parcels.'"$geom"')=0 THEN source_parcels.'"$land_use_value"' ELSE (1-(ST_Distance(target_parcels.'"$geom"',source_parcels.'"$geom"')/'"$distance"'))*source_parcels.'"$land_use_value"' END AS value_target, '
elif [ $formula = "ga" ]
then
query='source_parcels.'"$land_use_value"'*((2.718281828459045235360287471352662497757247093699959574966^(((ST_Distance(target_parcels.'"$geom"',source_parcels.'"$geom"')/'"$distance"')*(ST_Distance(target_parcels.'"$geom"',source_parcels.'"$geom"')/'"$distance"')*-4)+0.92))/sqrt(6.283185307179586476925286766559005768394338798750211641949)) AS value_target, '
fi

##RUN THE ANALYSIS
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.raw_data AS \
SELECT \
   row_number() OVER () AS gid, \
   source_parcels.gid AS id_source, \
   source_parcels.$land_use_class AS class_source, \
   target_parcels.gid AS id_target, \
   target_parcels.$land_use_class AS class_target, \
   $query
   ST_Distance(target_parcels.$geom, source_parcels.$geom) AS distance, \
   ST_ShortestLine(target_parcels.$geom, source_parcels.$geom) AS geom, \
   source_parcels.geom AS geom_source, target_parcels.geom AS geom_target, \
   source_parcels.bbox AS bbox_source, target_parcels.bbox AS bbox_target \
 FROM \
   (SELECT DISTINCT ON (geom) *
    FROM $schemaname.source_parcels) AS source_parcels \
 CROSS JOIN LATERAL \
   (SELECT * \
    FROM $schemaname.target_parcels \
    ) AS target_parcels \
    WHERE ST_Distance(target_parcels.$geom, source_parcels.$geom) < $distance \
         ORDER BY distance;"

PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
        CREATE TABLE $schemaname.results AS \
        SELECT
        row_number() OVER () AS gid, \
        id_target, class_target, \
        sum(value_target) AS value, \
        ST_Union(geom_target) AS geom FROM
        $schemaname.raw_data \
        GROUP BY id_target,class_target,geom_target;"

##RASTERIZE RESULTS
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.result_raster AS
select row_number() OVER () AS rid,
ST_asRaster(geom, $resolution. , -$resolution. , '32BF', value, -9999)
AS rast FROM $schemaname.results;"

##EXPORT REUSULTS TO A GEOPACKAGE
echo -e "Exporting the results in Geopackage format..."
gdal_rasterize -q -l $schemaname.results -a value -tr $resolution $resolution -a_nodata -9999.0 -ot Float32 -of GTiff "PG:dbname=$dbname host=localhost port=5432 user=$username password=$password sslmode=disable" $path/$schemaname'_results_rasterized'.tif
gdal_translate -q -of GPKG $path/$schemaname'_results_rasterized'.tif $path/$schemaname.gpkg -co RASTER_TABLE=results_rasterized
ogr2ogr -f GPKG $path/$schemaname.gpkg "PG:dbname=$dbname host=localhost port=5432 user=$username password=$password sslmode=disable schemas=$schemaname" -update
rm $path/$schemaname'_results_rasterized'.tif

echo ""
echo -e "Analysis finished"
output_abs_path="$(readlink -f $path/$schemaname.gpkg)"
echo -e "Results saved in ${RED}$output_abs_path${NC}"
