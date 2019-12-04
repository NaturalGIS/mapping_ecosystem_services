#!/bin/bash
while true; do
    read -p "Install PostgreSQL and PostGIS packages? " input_type
    case $input_type in
        Y) break;;
        N) break;;
        q ) echo "Quitting the program"; exit;;
        * ) echo "Please choose Y or N ('q' to quit)";;
    esac
done

if [ $input_type = 'Y' ]
then
  sudo apt-get update
  sudo apt-get dist-upgrade
  sudo apt-get install postgresql-10 postgresql-10-postgis-2.4 postgresql-10-postgis-scripts
fi

read -p "PostgreSQL/PostGIS database name (default=land): "  dbname
read -p "PostgreSQL/PostGIS username (default=land): " username

if [ -z "$dbname" ]
then
      dbname="land"
fi

if [ -z "$username" ]
then
      username="land"
fi

sudo -u postgres createuser $username -P
sudo -u postgres createdb $dbname --o $username
sudo -u postgres psql -d $dbname -c 'CREATE EXTENSION postgis;'
sudo -u postgres psql -d $dbname -c 'GRANT ALL ON geometry_columns TO '"$username"';'
