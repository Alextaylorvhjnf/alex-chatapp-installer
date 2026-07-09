#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"
SCRIPT_DIR="$BASE_DIR/scripts"

if [ -f "$SCRIPT_DIR/functions.sh" ]; then
    source "$SCRIPT_DIR/functions.sh"
else
    echo "Error: functions.sh not found"
    exit 1
fi

if [ -f "$SCRIPT_DIR/docker.sh" ]; then
    source "$SCRIPT_DIR/docker.sh"
else
    echo "Error: docker.sh not found"
    exit 1
fi

clear

echo
echo "========================================"
echo "      Alex ChatApp Installation"
echo "========================================"
echo

require_root

print_info "Checking operating system..."
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "OS: $PRETTY_NAME"
fi

print_info "Checking Docker..."
check_docker
check_compose

echo
echo "========================================"
echo "Domain Configuration"
echo "========================================"
echo "Domain: matrix.shikpooshaan.ir"
echo "Element: chatapp.shikpooshaan.ir"
echo

print_info "Creating directories..."
mkdir -p $BASE_DIR/{postgres,synapse,element,backups}
print_ok "Directories created"

print_info "Copying configuration files..."
cp $BASE_DIR/templates/docker-compose.yml.tpl $BASE_DIR/docker-compose.yml
cp $BASE_DIR/templates/homeserver.yaml.tpl $BASE_DIR/synapse/homeserver.yaml
cp $BASE_DIR/templates/element-config.json.tpl $BASE_DIR/element/config.json
print_ok "Configuration copied"

print_info "Starting Docker services..."
cd $BASE_DIR
docker compose up -d
print_ok "Containers started"

echo
echo "========================================"
echo " Installation Finished"
echo "========================================"
echo
echo "Element: https://chatapp.shikpooshaan.ir"
echo "Matrix: https://matrix.shikpooshaan.ir"
echo
print_ok "Alex ChatApp installed successfully"
