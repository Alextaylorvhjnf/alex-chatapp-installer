#!/bin/bash

set -e


BASE_DIR="/opt/chatapp"
CONTAINER="chatapp-synapse"

source $BASE_DIR/scripts/functions.sh


clear


echo
echo "========================================"
echo " Alex ChatApp Media Cleanup"
echo "========================================"
echo


require_root



# Default retention

RETENTION_DAYS=10



if [ -f "$BASE_DIR/.env" ]

then

source $BASE_DIR/.env


if [ ! -z "$MEDIA_RETENTION_DAYS" ]

then

RETENTION_DAYS=$MEDIA_RETENTION_DAYS

fi


fi



print_info "Retention period: $RETENTION_DAYS days"



# Check container


if ! docker ps | grep -q $CONTAINER

then

print_error "Synapse container is not running"

exit 1

fi



# Before size


BEFORE=$(docker exec $CONTAINER du -sh /data/media_store | awk '{print $1}')



echo

print_info "Media size before cleanup: $BEFORE"



# Cleanup


print_info "Removing old Matrix media..."



docker exec $CONTAINER find /data/media_store \
-type f \
-mtime +$RETENTION_DAYS \
-delete



# After size


AFTER=$(docker exec $CONTAINER du -sh /data/media_store | awk '{print $1}')



echo


print_ok "Cleanup completed"



echo

echo "========================================"

echo "Before : $BEFORE"

echo "After  : $AFTER"

echo "========================================"



log "Matrix media cleanup completed"


