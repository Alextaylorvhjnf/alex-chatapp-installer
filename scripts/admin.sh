#!/bin/bash
set -e

BASE_DIR="/opt/chatapp"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[i]${NC} $1"; }
print_ok() { echo -e "${GREEN}[✔]${NC} $1"; }
print_error() { echo -e "${RED}[✘]${NC} $1"; }

clear
echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo

[ "$EUID" -ne 0 ] && { print_error "Run as root"; exit 1; }

if ! docker ps --format "{{.Names}}" | grep -q "^chatapp-synapse$"; then
    print_error "Synapse container is not running"
    read -p "Press Enter..."
    exit 0
fi

echo
read -p "Matrix username: " USERNAME

if [ -z "$USERNAME" ]; then
    print_error "Username cannot be empty"
    read -p "Press Enter..."
    exit 0
fi

read -s -p "Password: " PASSWORD
echo

if [ -z "$PASSWORD" ]; then
    print_error "Password cannot be empty"
    read -p "Press Enter..."
    exit 0
fi

SERVER_NAME=$(grep '^server_name:' "$BASE_DIR/synapse/homeserver.yaml" | head -1 | sed 's/server_name://' | tr -d ' "')
[ -z "$SERVER_NAME" ] && SERVER_NAME="localhost"

echo
print_info "Creating Matrix admin user..."

docker exec -i chatapp-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008 -u "$USERNAME" -p "$PASSWORD" --admin

echo
print_ok "Admin user created successfully"
echo
echo "Username: @${USERNAME}:${SERVER_NAME}"
echo "Server: ${SERVER_NAME}"
echo
read -p "Press Enter..."
