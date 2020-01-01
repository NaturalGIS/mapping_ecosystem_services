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
	 echo "Usage: cmd [-d database name] [-u database username] [-p database password] [-s path to folder containing input datasources] [-m analysis distance] [-f analysis formula] [-t] analysis type [-r raster output spatial resolution]"  && exit
      ;;
  esac
done

##CHECK IF ALL PARAMETERS ARE SET
if [ ! "$dbname" ] || [ ! "$username" ] || [ ! "$password" ] || [ ! "$datasource" ] || [ ! "$distance" ] || [ ! "$formula" ] || [ ! "$type" ] || [ ! "$resolution" ]
then
    echo "Missing mandatory parameter"
    echo "Usage: cmd [-d database name] [-u database username] [-p database password] [-s path to folder containing input datasources] [-m analysis distance] [-f analysis formula] [-t] analysis type [-r raster output spatial resolution]"  && exit
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
  #echo "Database schema name already exists, wait at least 1 minute before running the analysis" && exit
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
sa_extent="$(ogrinfo -so $datasource $study_area_layer| grep -w 'Extent:' | sed 's/) - (/ /g' | sed 's/,//g'| sed 's/(//g'| sed 's/)//g'| sed 's/Extent: //g')"

#IMPORT THE STUDY AREA AND LAND USE LAYERS
echo "Importing study area map..."
ogr2ogr -q -progress --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=YES -lco SCHEMA=$schemaname -lco GEOMETRY_NAME=geom -lco FID=gid -nln study_area -nlt MULTIPOLYGON $datasource study_area
echo "Importing land use map..."
ogr2ogr -q --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SPATIAL_INDEX=YES -lco SCHEMA=$schemaname -lco GEOMETRY_NAME=geom -lco FID=gid -nln land_use -nlt MULTIPOLYGON -dialect SQLITE -sql "SELECT ST_Intersection(a.geom,ST_Buffer(b.geom,2*$distance)) AS geom,a.* FROM land_use a, study_area b WHERE ST_Intersects(a.geom,ST_Buffer(b.geom,2*$distance))" $datasource


echo -e "Creating the 'source' and 'target' patches layers..."
#CREATE THE SOURCE PATCHES LAYER
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.source_patches AS \
SELECT a.*, ST_Multi(ST_MakeValid(a.geom))::geometry('MULTIPOLYGON', $crs) AS geom_valid, ST_Multi(ST_Envelope(a.geom))::geometry('MULTIPOLYGON', $crs) AS bbox \
FROM $schemaname.land_use a, $schemaname.study_area b \
WHERE a.type = 'source' AND ST_Intersects(a.geom,b.geom) IS TRUE;"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.source_patches ADD PRIMARY KEY (gid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_geom_valid_idx ON $schemaname.source_patches USING gist (geom_valid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_bbox_idx ON $schemaname.source_patches USING gist (bbox);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX sp_geom_idx ON $schemaname.source_patches USING gist (geom);"

#CREATE THE TARGET PATCHES LAYER
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.target_patches AS \
SELECT a.*, ST_Multi(ST_MakeValid(a.geom))::geometry('MULTIPOLYGON', $crs) AS geom_valid, ST_Multi(ST_Envelope(a.geom))::geometry('MULTIPOLYGON', $crs) AS bbox \
FROM $schemaname.land_use a, $schemaname.study_area b \
WHERE a.type = 'target' AND ST_Intersects(a.geom,b.geom) IS TRUE;"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "ALTER TABLE $schemaname.target_patches ADD PRIMARY KEY (gid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_geom_valid_idx ON $schemaname.target_patches USING gist (geom_valid);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_bbox_idx ON $schemaname.target_patches USING gist (bbox);"
PGPASSWORD=$password psql -q -h localhost -d $dbname -U $username -c "CREATE INDEX tp_geom_idx ON $schemaname.target_patches USING gist (geom);"

echo -e "Processing the data within the database..."
##SET THE GEOMETRIES NAMES
if [ $type = "bb" ]
then
geom='bbox'
elif [ $type = "bo" ]
then
geom='geom_valid'
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
