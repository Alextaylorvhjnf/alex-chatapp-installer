#!/bin/bash

VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

logo() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║                                              ║"
    echo "║        █████╗ ██╗     ███████╗██╗  ██╗       ║"
    echo "║       ██╔══██╗██║     ██╔════╝╚██╗██╔╝       ║"
    echo "║       ███████║██║     █████╗   ╚███╔╝        ║"
    echo "║       ██╔══██║██║     ██╔══╝   ██╔██╗        ║"
    echo "║       ██║  ██║███████╗███████╗██╔╝ ██╗       ║"
    echo "║       ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ║"
    echo "║                                              ║"
    echo "║          Alex ChatApp Installer              ║"
    echo "║          Matrix + Synapse + Element          ║"
    echo "║          Version: $VERSION                       ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

system_info() {
    echo ""
    echo -e "${YELLOW}System Information${NC}"
    echo "------------------"
    echo "Hostname : $(hostname)"
    echo "OS       : $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "CPU      : $(nproc) cores"
    echo "RAM      : $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Disk     : $(df -h / | awk 'NR==2 {print $4}') free"
    echo ""
}

main_menu() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║                 MAIN MENU                    ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║  1) 🚀 Install New ChatApp                   ║"
    echo "║  2) 🔄 Update ChatApp                        ║"
    echo "║  3) 💾 Backup System                         ║"
    echo "║  4) 🧹 Cleanup Media                         ║"
    echo "║  5) 📊 Server Status                         ║"
    echo "║  6) 🔐 SSL Manager                           ║"
    echo "║  7) 👤 Admin Manager                         ║"
    echo "║  8) 🛡 Security Manager                      ║"
    echo "║  9) 🛠 Repair Manager                        ║"
    echo "║ 10) 📋 Log Viewer                            ║"
    echo "║ 11) ⚙ Service Manager                        ║"
    echo "║ 12) 🗄 Database Manager                      ║"
    echo "║ 13) ❤️ Health Check                          ║"
    echo "║  0) Exit                                     ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

[ "$EUID" -ne 0 ] && { echo -e "${RED}Run as root!${NC}"; exit 1; }

while true; do
    clear
    logo
    system_info
    main_menu
    read -p "Select option: " choice
    case $choice in
        1)
            SCRIPT="$SCRIPTS_DIR/install.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo -e "${RED}Error: $SCRIPT not found${NC}"
            read -p "Press Enter..."
            ;;
        2)
            SCRIPT="$SCRIPTS_DIR/update.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        3)
            SCRIPT="$SCRIPTS_DIR/backup.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        4)
            SCRIPT="$SCRIPTS_DIR/cleanup.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        5)
            SCRIPT="$SCRIPTS_DIR/status.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        6)
            SCRIPT="$SCRIPTS_DIR/ssl.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        7)
            SCRIPT="$SCRIPTS_DIR/admin.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        8)
            SCRIPT="$SCRIPTS_DIR/security.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        9)
            SCRIPT="$SCRIPTS_DIR/repair.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        10)
            SCRIPT="$SCRIPTS_DIR/logs.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        11)
            SCRIPT="$SCRIPTS_DIR/service.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        12)
            SCRIPT="$SCRIPTS_DIR/database.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        13)
            SCRIPT="$SCRIPTS_DIR/health.sh"
            [ -f "$SCRIPT" ] && bash "$SCRIPT" || echo "Coming soon..."
            read -p "Press Enter..."
            ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
