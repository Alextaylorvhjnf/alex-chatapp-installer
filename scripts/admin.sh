#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_ok() { echo -e "${GREEN}[✔]${NC} $1"; }
print_error() { echo -e "${RED}[✘]${NC} $1"; }

clear
echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo
echo "1) Create new user"
echo "2) Create admin user"
echo "3) List users"
echo "4) Deactivate user"
echo "5) Reset password"
echo "0) Back"
echo
read -p "Select option: " choice

case $choice in
    1)
        read -p "Username: " USERNAME
        read -sp "Password: " PASSWORD
        echo
        docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$USERNAME" -p "$PASSWORD" --no-admin
        print_ok "User $USERNAME created"
        ;;
    2)
        read -p "Username: " USERNAME
        read -sp "Password: " PASSWORD
        echo
        docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$USERNAME" -p "$PASSWORD" --admin
        print_ok "Admin $USERNAME created"
        ;;
    3)
        echo "Users:"
        docker exec chatapp-postgres psql -U synapse -d synapse -c "SELECT name, admin, deactivated FROM users;" 2>/dev/null || echo "Cannot fetch users"
        ;;
    4)
        read -p "Username to deactivate: " USERNAME
        docker exec chatapp-postgres psql -U synapse -d synapse -c "UPDATE users SET deactivated = 1 WHERE name = '@${USERNAME}:matrix.shikpooshaan.ir';" 2>/dev/null
        print_ok "User $USERNAME deactivated"
        ;;
    5)
        read -p "Username: " USERNAME
        read -sp "New password: " PASSWORD
        echo
        HASH=$(docker exec chatapp-synapse hash_password -p "$PASSWORD" 2>/dev/null | tail -1)
        [ -n "$HASH" ] && docker exec chatapp-postgres psql -U synapse -d synapse -c "UPDATE users SET password_hash = '$HASH' WHERE name = '@${USERNAME}:matrix.shikpooshaan.ir';" 2>/dev/null
        print_ok "Password reset for $USERNAME"
        ;;
    0) exit 0 ;;
    *) echo "Invalid";;
esac

read -p "Press Enter..."
