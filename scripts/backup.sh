#!/bin/bash

set -e


BASE_DIR="/opt/chatapp"

BACKUP_DIR="$BASE_DIR/backups"


DATE=$(date +"%Y-%m-%d_%H-%M-%S")


mkdir -p "$BACKUP_DIR"



echo "========================================"
echo " Alex ChatApp Backup"
echo "========================================"


echo "[1/4] Backing up PostgreSQL..."



docker exec chatapp-postgres \
pg_dump \
-U synapse \
synapse \
> "$BACKUP_DIR/postgres_$DATE.sql"



echo "PostgreSQL backup completed"



echo "[2/4] Backing up Synapse configuration..."



tar --exclude="synapse/media_store" \
-czf \
"$BACKUP_DIR/synapse_$DATE.tar.gz" \
-C "$BASE_DIR" \
synapse


echo "Synapse backup completed"



echo "[3/4] Backing up Element configuration..."



tar -czf \
"$BACKUP_DIR/element_$DATE.tar.gz" \
-C "$BASE_DIR" \
element



echo "Element backup completed"



echo "[4/4] Cleaning old backups..."



find "$BACKUP_DIR" \
-type f \
-mtime +30 \
-delete



echo

echo "========================================"
echo " Backup completed"
echo " Location:"
echo "$BACKUP_DIR"
echo "========================================"
