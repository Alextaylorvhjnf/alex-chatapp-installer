#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"
SCRIPT_DIR="$BASE_DIR/scripts"

# Source functions
[ -f "$SCRIPT_DIR/functions.sh" ] && source "$SCRIPT_DIR/functions.sh" || { echo "Error: functions.sh not found"; exit 1; }
[ -f "$SCRIPT_DIR/docker.sh" ] && source "$SCRIPT_DIR/docker.sh" || { echo "Error: docker.sh not found"; exit 1; }

clear
echo
echo "========================================"
echo "      Alex ChatApp Installation"
echo "========================================"
echo

require_root

print_info "Checking operating system..."
[ -f /etc/os-release ] && source /etc/os-release && echo "OS: $PRETTY_NAME" || { print_error "Unknown OS"; exit 1; }

print_info "Checking Docker..."
check_docker
check_compose

echo
echo "========================================"
echo "Domain Configuration"
echo "========================================"
echo
read -p "Enter ChatApp domain: " CHAT_DOMAIN
read -p "Enter Matrix domain: " MATRIX_DOMAIN

[ -z "$CHAT_DOMAIN" ] && { print_error "ChatApp domain cannot be empty"; exit 1; }
[ -z "$MATRIX_DOMAIN" ] && { print_error "Matrix domain cannot be empty"; exit 1; }

print_info "Generating security secrets..."
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REGISTRATION_SECRET=$(openssl rand -hex 16)
MACAROON_SECRET=$(openssl rand -hex 16)
FORM_SECRET=$(openssl rand -hex 16)

cat > /opt/chatapp/.env <<ENVEOF
CHAT_DOMAIN=$CHAT_DOMAIN
MATRIX_DOMAIN=$MATRIX_DOMAIN
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REGISTRATION_SECRET=$REGISTRATION_SECRET
MACAROON_SECRET=$MACAROON_SECRET
FORM_SECRET=$FORM_SECRET
ENVEOF
chmod 600 /opt/chatapp/.env
print_ok "Environment created"

print_info "Creating directories..."
mkdir -p "$BASE_DIR"/{postgres,synapse,element,backups}
print_ok "Directories created"

print_info "Generating configs..."
source /opt/chatapp/.env

# docker-compose.yml
cat > "$BASE_DIR/docker-compose.yml" <<COMPOSE
services:
  postgres:
    image: postgres:16
    container_name: chatapp-postgres
    restart: always
    environment:
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_DB: synapse
      POSTGRES_INITDB_ARGS: "--locale=C --encoding=UTF8"
    volumes:
      - ./postgres:/var/lib/postgresql/data
    networks:
      - chatapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synapse"]
      interval: 10s
      timeout: 5s
      retries: 5

  synapse:
    image: matrixdotorg/synapse:v1.156.0
    container_name: chatapp-synapse
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8008:8008"
      - "8448:8448"
    volumes:
      - ./synapse:/data
    environment:
      - SYNAPSE_SERVER_NAME=$MATRIX_DOMAIN
      - SYNAPSE_REPORT_STATS=no
    networks:
      - chatapp
    healthcheck:
      test: ["CMD-SHELL", "curl -fSs http://localhost:8008/health || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s

  element:
    image: vectorim/element-web:latest
    container_name: chatapp-element
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./element/config.json:/app/config.json
    networks:
      - chatapp
    healthcheck:
      test: ["CMD-SHELL", "curl -fSs http://localhost:80 || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 5

networks:
  chatapp:
    driver: bridge
COMPOSE

# homeserver.yaml
cat > "$BASE_DIR/synapse/homeserver.yaml" <<HOMESERVER
server_name: "$MATRIX_DOMAIN"
pid_file: /data/homeserver.pid

listeners:
  - port: 8008
    type: http
    tls: false
    x_forwarded: true
    bind_addresses:
      - 0.0.0.0
    resources:
      - names:
          - client
          - federation
        compress: false

database:
  name: psycopg2
  args:
    user: synapse
    password: "$POSTGRES_PASSWORD"
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

media_store_path: /data/media_store
registration_shared_secret: "$REGISTRATION_SECRET"
report_stats: false
macaroon_secret_key: "$MACAROON_SECRET"
form_secret: "$FORM_SECRET"
signing_key_path: "/data/$MATRIX_DOMAIN.signing.key"

trusted_key_servers:
  - server_name: "matrix.org"

enable_registration: true
enable_registration_without_verification: true
max_upload_size: 500M
HOMESERVER

# element config.json
cat > "$BASE_DIR/element/config.json" <<ELEMENT
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$MATRIX_DOMAIN",
            "server_name": "$MATRIX_DOMAIN"
        }
    },
    "brand": "Alex ChatApp",
    "roomDirectory": {
        "servers": ["matrix.org"]
    }
}
ELEMENT

# Fix permissions
chown -R 991:991 "$BASE_DIR/synapse" 2>/dev/null || true

print_ok "Configuration generated"

print_info "Starting Docker services..."
cd "$BASE_DIR"
docker compose up -d

# Wait for healthy
echo "Waiting for services to be healthy..."
sleep 30

print_ok "Containers started"

echo
echo "========================================"
echo " Installation Finished"
echo "========================================"
echo
echo "ChatApp: http://$(hostname -I | awk '{print $1}'):8080"
echo "Matrix:  http://$(hostname -I | awk '{print $1}'):8008"
echo
echo "For production, setup Nginx/Apache reverse proxy"
echo "with SSL for: $CHAT_DOMAIN and $MATRIX_DOMAIN"
echo
print_ok "Alex ChatApp installed successfully!"
