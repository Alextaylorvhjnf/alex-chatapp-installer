#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"

source $BASE_DIR/scripts/functions.sh

clear

echo
echo "========================================"
echo "       Alex ChatApp Service Manager"
echo "========================================"
echo


echo "1) Start Services"
echo "2) Stop Services"
echo "3) Restart Services"
echo "4) Rebuild Containers"
echo "5) Container Status"
echo "0) Exit"

echo

read -p "Choose: " OPTION


cd $BASE_DIR


case $OPTION in


1)

docker-compose up -d

print_ok "Services started"

;;


2)

docker-compose down

print_ok "Services stopped"

;;


3)

docker-compose restart

print_ok "Services restarted"

;;


4)

docker-compose down

docker-compose pull

docker-compose up -d

print_ok "Containers rebuilt"

;;


5)

docker ps --format "table {{.Names}}\t{{.Status}}"

;;


0)

exit 0

;;

esac


read -p "Press Enter..."
