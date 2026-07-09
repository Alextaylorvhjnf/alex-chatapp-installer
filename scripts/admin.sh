#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

print_ok() { echo -e "${GREEN}[✔]${NC} $1"; }
print_error() { echo -e "${RED}[✘]${NC} $1"; }

clear
echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo

if ! docker ps --format "{{.Names}}" | grep -q "chatapp-synapse"; then
    print_error "Synapse not running"
    read -p "Press Enter..."
    exit 0
fi

echo "1) Create normal user"
echo "2) Create admin user"
echo "3) List users"
echo "0) Back"
echo
read -p "Select: " opt

if [ "$opt" = "1" ] || [ "$opt" = "2" ]; then
    echo
    read -p "Username: " u
    read -s -p "Password: " p
    echo
    
    if [ -z "$u" ] || [ -z "$p" ]; then
        print_error "Username and password required"
    else
        flag="--no-admin"
        [ "$opt" = "2" ] && flag="--admin"
        docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$u" -p "$p" $flag
        print_ok "Done! Login: @$u:matrix.shikpooshaan.ir"
    fi
elif [ "$opt" = "3" ]; then
    docker exec chatapp-postgres psql -U synapse -d synapse -c "SELECT name, admin FROM users;" 2>/dev/null || echo "Error"
fi

read -p "Press Enter..."
