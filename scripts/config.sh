#!/bin/bash


BASE_DIR="/opt/chatapp"


echo
echo "========================================"
echo " Alex ChatApp Configuration"
echo "========================================"
echo


read -p "Enter ChatApp domain: " CHAT_DOMAIN


read -p "Enter Matrix domain: " MATRIX_DOMAIN



cat > $BASE_DIR/.env <<EOF

CHAT_DOMAIN=$CHAT_DOMAIN

MATRIX_DOMAIN=$MATRIX_DOMAIN

MEDIA_RETENTION_DAYS=10

BACKUP_RETENTION_DAYS=7

EOF



echo

echo "Configuration saved"

echo "$BASE_DIR/.env"
