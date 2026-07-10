#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

print_ok() { echo -e "${GREEN}[✔]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }
print_error() { echo -e "${RED}[✘]${NC} $1"; }

clear
echo
echo "========================================"
echo "       Alex ChatApp Updater"
echo "========================================"
echo

print_info "Updating from GitHub..."
cd /opt/chatapp
git pull origin main 2>&1 && print_ok "Code updated" || print_error "Git pull failed"

print_info "Pulling latest Docker images..."
docker-compose pull 2>&1 && print_ok "Images pulled" || print_error "Pull failed"

print_info "Restarting services..."
docker-compose up -d 2>&1 && print_ok "Services restarted" || print_error "Restart failed"

echo
print_ok "Update complete!"
echo
read -s -n 1 -p "Press any key to return..." </dev/tty
echo
