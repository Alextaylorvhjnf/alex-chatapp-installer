#!/bin/bash

VERSION="1.0.0"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "║                                              ║"
    echo "║          Version: $VERSION                       ║"
    echo "║                                              ║"
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
    echo "║                                              ║"
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
    echo "║                                              ║"
    echo "║  0) Exit                                     ║"
    echo "║                                              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

run_script() {
    local script="$SCRIPTS_DIR/$1.sh"
    if [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: $script not found${NC}"
    fi
    echo ""
    read -p "Press Enter..."
}

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

while true; do
    clear
    logo
    system_info
    main_menu
    read -p "Select option: " choice
    case $choice in
        1) run_script "install" ;;
        2) run_script "update" ;;
        3) run_script "backup" ;;
        4) run_script "cleanup" ;;
        5) run_script "status" ;;
        6) run_script "ssl" ;;
        7) run_script "admin" ;;
        8) run_script "security" ;;
        9) run_script "repair" ;;
        10) run_script "logs" ;;
        11) run_script "service" ;;
        12) run_script "database" ;;
        13) run_script "health" ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
