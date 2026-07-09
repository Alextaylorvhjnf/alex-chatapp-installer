#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"

source $BASE_DIR/scripts/functions.sh


clear


echo
echo "========================================"
echo "        Alex ChatApp Log Manager"
echo "========================================"
echo


require_root


echo

echo "Select log source:"
echo

echo "1) Synapse"
echo "2) PostgreSQL"
echo "3) Element"
echo "4) Nginx"
echo "5) Docker System"
echo "0) Back"

echo


read -p "Choose: " OPTION


echo

read -p "Number of lines [50]: " LINES


if [ -z "$LINES" ]
then
    LINES=50
fi



case $OPTION in


1)

echo "---- Synapse Logs ----"

docker logs chatapp-synapse --tail $LINES

;;


2)

echo "---- PostgreSQL Logs ----"

docker logs chatapp-postgres --tail $LINES

;;


3)

echo "---- Element Logs ----"

docker logs chatapp-element --tail $LINES

;;


4)

echo "---- Nginx Logs ----"

tail -n $LINES /var/log/nginx/error.log

;;


5)

echo "---- Docker Events ----"

journalctl -u docker --no-pager -n $LINES

;;


0)

exit 0

;;


*)

echo "Invalid option"

;;

esac


echo

read -p "Press Enter..."

