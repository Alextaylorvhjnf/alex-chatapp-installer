#!/bin/bash
set -e

BASE_DIR="/opt/chatapp"

# Simple print functions (no dependency on functions.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[i]${NC} $1"; }
print_ok() { echo -e "${GREEN}[✔]${NC} $1"; }
print_error() { echo -e "${RED}[✘]${NC} $1"; }

clear
echo
echo "========================================"
echo "      Alex ChatApp Installation"
echo "========================================"
echo

# Check root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# Check OS
print_info "Checking operating system..."
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "OS: $PRETTY_NAME"
fi

# Check Docker
print_info "Checking Docker..."
if ! command -v docker &>/dev/null; then
    print_info "Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
fi
print_ok "Docker installed"

# Check Docker Compose
print_info "Checking Docker Compose..."
if ! docker compose version &>/dev/null; then
    print_error "Docker Compose not found"
    exit 1
fi
print_ok "Docker Compose plugin available"

echo
echo "========================================"
echo "Domain Configuration"
echo "========================================"
echo

read -p "Enter ChatApp domain: " CHAT_DOMAIN
read -p "Enter Matrix domain: " MATRIX_DOMAIN

if [ -z "$CHAT_DOMAIN" ] || [ -z "$MATRIX_DOMAIN" ]; then
    print_error "Domain cannot be empty"
    exit 1
fi

print_info "Generating security secrets..."
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REGISTRATION_SECRET=$(openssl rand -hex 16)
MACAROON_SECRET=$(openssl rand -hex 16)
FORM_SECRET=$(openssl rand -hex 16)

cat > "$BASE_DIR/.env" <<ENVEOF
CHAT_DOMAIN=$CHAT_DOMAIN
MATRIX_DOMAIN=$MATRIX_DOMAIN
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REGISTRATION_SECRET=$REGISTRATION_SECRET
MACAROON_SECRET=$MACAROON_SECRET
FORM_SECRET=$FORM_SECRET
ENVEOF
chmod 600 "$BASE_DIR/.env"
print_ok "Environment created"

print_info "Creating directories..."
mkdir -p "$BASE_DIR"/{postgres,synapse,element,backups}
print_ok "Directories created"

print_info "Generating docker-compose.yml..."
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

print_info "Generating homeserver.yaml..."
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

print_info "Generating element config..."
cat > "$BASE_DIR/element/config.json" <<ELEMENT
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$MATRIX_DOMAIN",
            "server_name": "$MATRIX_DOMAIN"
        }
    },
    "brand": "Alex ChatApp"
}
ELEMENT

chown -R 991:991 "$BASE_DIR/synapse" 2>/dev/null || true
print_ok "Configuration generated"

rm -rf "$BASE_DIR/postgres"
print_info "Starting Docker services..."
cd "$BASE_DIR"
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d
sleep 30
print_ok "Containers started"

IP=$(hostname -I | awk '{print $1}')
echo
echo "========================================"
echo " Installation Finished"
echo "========================================"
echo
echo "ChatApp: http://$IP:8080"
echo "Matrix:  http://$IP:8008"
echo
print_ok "Done!"
echo
read -p "Press Enter..."
