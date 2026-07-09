#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"

SERVER_NAME=$(awk '/^server_name:/ {gsub(/[" ]/,"",$2); print $2; exit}' "$BASE_DIR/synapse/homeserver.yaml")

source "$BASE_DIR/scripts/functions.sh"

clear

echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo


require_root


# Check synapse container

if ! docker ps --format "{{.Names}}" | grep -q "^chatapp-synapse$"
then
    print_error "Synapse container is not running"
    exit 1
fi


echo

read -p "Matrix username: " USERNAME


if [ -z "$USERNAME" ]
then
    print_error "Username cannot be empty"
    exit 1
fi

if [[ "$USERNAME" =~ ^[0-9]+$ ]]
then
    print_error "Username cannot be numeric only"
    exit 1
fi

read -s -p "Password: " PASSWORD

echo


if [ -z "$PASSWORD" ]
then
    print_error "Password cannot be empty"
    exit 1
fi


# Get server name from homeserver config

SERVER_NAME=$(grep '^server_name:' "$BASE_DIR/synapse/homeserver.yaml" | head -1 | sed 's/server_name://' | tr -d ' "')

if [ -z "$SERVER_NAME" ]
then
    SERVER_NAME="localhost"
fi


echo

print_info "Creating Matrix admin user..."


docker exec -i chatapp-synapse \
register_new_matrix_user \
-c /data/homeserver.yaml \
http://localhost:8008 \
-u "$USERNAME" \
-p "$PASSWORD" \
-a


echo

print_ok "Admin user created successfully"


echo

echo "Login:"
echo

echo "Username:"
echo "@${USERNAME}:${SERVER_NAME}"

echo "Server:"
echo "${SERVER_NAME}"

echo
