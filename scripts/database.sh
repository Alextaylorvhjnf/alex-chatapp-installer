#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"


clear


echo
echo "========================================"
echo "       Alex ChatApp Database Manager"
echo "========================================"
echo


echo "1) Backup Database"
echo "2) Restore Database"
echo "3) Database Status"
echo "0) Exit"


read -p "Choose: " OPTION



case $OPTION in


1)

mkdir -p $BASE_DIR/backups


docker exec chatapp-postgres \
pg_dumpall -U postgres \
> $BASE_DIR/backups/postgres_$(date +%F_%H-%M).sql


echo "Database backup completed"

;;


2)

echo "Available backups:"

ls $BASE_DIR/backups


read -p "Backup file: " FILE


cat $BASE_DIR/backups/$FILE | \
docker exec -i chatapp-postgres \
psql -U postgres


echo "Restore completed"

;;


3)

docker exec chatapp-postgres \
pg_isready


;;


0)

exit

;;

esac


read -p "Press Enter..."
