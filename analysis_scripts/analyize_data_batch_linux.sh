#!/bin/bash

#ASK THE USER A FEW QUESTIONS
while true; do
    read -p "Enter de database name: " dbname
    case $dbname in
        (*[a-z]*) break;;
        q ) echo "Quitting the program"; exit;;
        * ) echo "Please enter the database name ('q' to quit)";;
    esac
done

while true; do
    read -p "Enter de database username: " username
    case $username in
        (*[a-z]*) break;;
        q ) echo "Quitting the program"; exit;;
        * ) echo "Please enter the database username ('q' to quit)";;
    esac
done

while true; do
    read -p "Enter de database password: " password
    case $password in
        (*[a-z]*) break;;
        q ) echo "Quitting the program"; exit;;
        * ) echo "Please enter the database password ('q' to quit)";;
    esac
done

#CHECK IF IS POSSIBLE TO ESTABLISH A CONNECTION TO THE DATABASE AND IF IT HAS POSTGIS IN IT
message=$(PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "SELECT * FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';" 2>&1 >/dev/null)

if [[ $message == *"FATAL"* ]]; then
  echo "PostgreSQL username and/or password and/or database name are wrong" && exit
fi

message=$(PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "SELECT * FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';" | grep spatial)

if [[ $message != *"spatial_ref_sys"* ]]; then
  echo "The chosen PostgreSQL database does not have the PostGIS extension installed" && exit
fi

#ASK THE USER A FEW MORE QUESTIONS
read -p "Absolute path to a FOLDER containing GEOPACKAGE datasources: " path_to
read -p "Analysis distance in map/CRS units (default=500): " distance

while true; do
    read -p "Formula to use, 'gaussian' ('ga) or 'linear' ('li'): " formula
    case $formula in
        ga) break;;
        li) break;;
        q ) echo "Quitting the program"; exit;;
        * ) echo "Please the formula to use ('q' to quit)";;
    esac
done
#read -p "Formula to use, 'gaussian' ('ga) or 'linear' ('li') (default 'linear'): " formula

while true; do
    read -p "Compute distances with patches bounding boxes ('bb') or boundaries ('bo'): " type
    case $type in
        bb) break;;
        bo) break;;
        q ) echo "Quitting the program"; exit;;
        * ) echo "Please choose bounding boxes or boundaries ('q' to quit)";;
    esac
done
#read -p "Compute distances with patches bounding boxes ('bb') or boundaries ('bo') (default='bb')?: " type

read -p "Raster output resolution in map/CRS units (must be an integer value, default=10): " resolution

if [ -z "$distance" ]
then
      distance="500"
fi

if [ -z "$resolution" ]
then
      resolution="10"
fi

FILES=$path_to/*.gpkg
for datasource in $FILES
do

nopath=$(basename -- "$datasource")
noext="${nopath%.*}"

#SET THE NAME FOR A SCHEMA IN THE DATABASE THAT WILL HOLD THE INPUT DATA AND THE RESULTS
schemaname=$noext"_"$formula"_"$type"_"$distance"_"$(date +'%m_%d_%Y_%H_%M')

#CHECK IF THE GPKG DATASOURCE EXIST
#if [ ! -f $datasource ]; then
#    echo "GPKG Datasource NOT found!" && exit
#fi

#epsg_sa="$(ogrinfo -so $sa_bound $noext | grep 3763)"

#if [ -z "$epsg_sa" ]
#then
#      echo "Study Area Datasource is NOT in EPSG:3763" && exit
#fi

#CREATE THE SCHEMA FOR THE RESULTS
PGPASSWORD=$password psql -q -U $username -d $dbname -h localhost -c "CREATE SCHEMA $schemaname;"
 
echo ""
echo -e "Starting Process!"
echo ""

#IMPORT THE STUDY AREA AND LAND USE LAYERS
echo "Importing study area map"
ogr2ogr -progress -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SCHEMA=$schemaname -lco GEOMETRY_NAME=geom -lco FID=gid -nln study_area -nlt MULTIPOLYGON $datasource study_area
echo ""
echo "Importing land use map"
ogr2ogr -progress --config PG_USE_COPY YES -f "PostgreSQL" "PG:host=localhost user=$username dbname=$dbname password=$password" -lco SCHEMA=$schemaname -lco GEOMETRY_NAME=geom -lco FID=gid -nln land_use -nlt MULTIPOLYGON $datasource land_use

#CREATE THE SOURCE PARCELS LAYER
PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.source_parcels AS \
SELECT a.*, ST_Envelope(a.geom) AS bbox \
FROM $schemaname.land_use a, $schemaname.study_area b \
WHERE a.type = 'source' AND ST_Intersects(a.geom,b.geom) IS TRUE;"

#CREATE THE TARGET PARCELS LAYER
PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.target_parcels AS \
SELECT a.*, ST_Envelope(a.geom) AS bbox \
FROM $schemaname.land_use a, $schemaname.study_area b \
WHERE a.type = 'target' AND ST_Intersects(a.geom,b.geom) IS TRUE;"

#SET THE GEOMETRIES NAMES
if [ $type = "bb" ]
then
geom='bbox'
elif [ $type = "bo" ]
then
geom='geom'
fi

#SET THE FORUMLAS
if [ $formula = "li" ]
then
query='CASE WHEN ST_Distance(target_parcels.'"$geom"', source_parcels.'"$geom"')=0 THEN source_parcels.value ELSE (1-(ST_Distance(target_parcels.'"$geom"',source_parcels.'"$geom"')/'"$distance"'))*source_parcels.value END AS value_target, '
elif [ $formula = "ga" ]
then
query='source_parcels.value*((2.718281828459045235360287471352662497757247093699959574966^(((ST_Distance(target_parcels.'"$geom"',source_parcels.'"$geom"')/'"$distance"')*(ST_Distance(target_parcels.'"$geom"',source_parcels.'"$geom"')/'"$distance"')*-4)+0.92))/sqrt(6.283185307179586476925286766559005768394338798750211641949)) AS value_target, '
fi

#RUN THE ANALYSIS   
PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.raw_data AS \
SELECT \
   row_number() OVER () AS gid, \
   source_parcels.gid AS id_source, \
   source_parcels.class AS class_source, \
   target_parcels.gid AS id_target, \
   target_parcels.class AS class_target, \
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
         
PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "\
        CREATE TABLE $schemaname.results AS \
        SELECT 
        row_number() OVER () AS gid, \
        id_target, class_target, \
        sum(value_target) AS value, \
        ST_Union(geom_target) AS geom FROM 
        $schemaname.raw_data \
        GROUP BY id_target,class_target,geom_target;"

#RASTERIZE RESULTS        
PGPASSWORD=$password psql -h localhost -d $dbname -U $username -c "\
CREATE TABLE $schemaname.result_raster AS
select row_number() OVER () AS rid,
ST_asRaster(geom, $resolution. , -$resolution. , '32BF', value, -9999)
AS rast FROM $schemaname.results;"

#EXPORT REUSULTS TO A GEOPACKAGE
gdal_rasterize -l $schemaname.results -a value -tr $resolution $resolution -a_nodata -9999.0 -ot Float32 -of GTiff "PG:dbname=$dbname host=localhost port=5432 user=$username password=$password sslmode=disable" $schemaname'_results_rasterized'.tif

gdal_translate -of GPKG $schemaname'_results_rasterized'.tif $schemaname.gpkg -co RASTER_TABLE=results_rasterized

ogr2ogr -f GPKG $schemaname.gpkg "PG:dbname=$dbname host=localhost port=5432 user=$username password=$password sslmode=disable schemas=$schemaname" -update

rm $schemaname'_results_rasterized'.tif

done
