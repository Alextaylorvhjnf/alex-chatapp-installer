#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"

source $BASE_DIR/scripts/functions.sh


clear


echo
echo "========================================"
echo "       Alex ChatApp Repair Manager"
echo "========================================"
echo


require_root


echo


print_info "Checking Docker..."


if ! systemctl is-active --quiet docker
then

    print_error "Docker is not running"

    systemctl restart docker

else

    print_ok "Docker running"

fi



echo


print_info "Checking containers..."


docker ps \
--format "table {{.Names}}\t{{.Status}}"



echo


read -p "Restart ChatApp services? (y/n): " RESTART



if [ "$RESTART" = "y" ]
then

    print_info "Restarting services..."

    cd $BASE_DIR

    docker-compose restart


    print_ok "Services restarted"

fi



echo


print_info "Checking nginx..."



if nginx -t >/dev/null 2>&1

then

    print_ok "Nginx configuration OK"

else

    print_error "Nginx configuration error"

fi



echo


print_info "Fixing permissions..."


chown -R root:root $BASE_DIR/scripts
chmod +x $BASE_DIR/scripts/*.sh



print_ok "Permissions fixed"



echo


echo "Recent Synapse logs"
echo "-------------------"


docker logs chatapp-synapse \
--tail 30 2>/dev/null || echo "Synapse container unavailable"



echo


echo "========================================"
echo " Repair completed"
echo "========================================"
