#!/bin/bash

set -e

REPO="https://github.com/Alextaylorvhjnf/alex-chatapp-installer.git"

INSTALL_DIR="/opt/chatapp"


echo "================================"
echo " Alex ChatApp Installer"
echo "================================"


apt update -y
apt install -y git


if [ -d "$INSTALL_DIR" ]; then
    echo "Existing installation found"
else
    git clone "$REPO" "$INSTALL_DIR"
fi


cd "$INSTALL_DIR"


chmod +x install.sh
chmod +x scripts/*.sh


bash install.sh
