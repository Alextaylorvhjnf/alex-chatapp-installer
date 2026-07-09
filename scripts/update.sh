#!/bin/bash

set -e


BASE_DIR="/opt/chatapp"


source $BASE_DIR/scripts/functions.sh


clear


echo
echo "========================================"
echo "       Alex ChatApp Update Manager"
echo "========================================"
echo



require_root



cd $BASE_DIR



# ==============================
# Backup Before Update
# ==============================


print_info "Creating backup before update..."


if [ -f "$BASE_DIR/scripts/backup.sh" ]

then

    bash $BASE_DIR/scripts/backup.sh

else

    print_warning "Backup script not found"

fi



# ==============================
# Git Update
# ==============================


print_info "Updating source code from GitHub..."


if [ -d ".git" ]

then

    git fetch origin

    git pull origin main

    print_ok "Source updated"

else

    print_warning "Git repository not detected"

fi



# ==============================
# Docker Update
# ==============================


print_info "Pulling latest Docker images..."


docker-compose pull


print_ok "Docker images updated"



# ==============================
# Recreate Services
# ==============================


print_info "Restarting ChatApp services..."


docker-compose up -d --remove-orphans


print_ok "Containers restarted"



# ==============================
# Cleanup
# ==============================


print_info "Cleaning unused Docker images..."


docker image prune -f



# ==============================
# Status
# ==============================


echo

print_info "Current container status"


docker ps \
--format "table {{.Names}}\t{{.Status}}"



echo

echo "========================================"

echo " Update completed successfully"

echo "========================================"
