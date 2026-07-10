#!/bin/bash

VERSION="1.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# CURL PIPE MODE
if [ ! -f /opt/chatapp/scripts/install.sh ]; then
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║        █████╗ ██╗     ███████╗██╗  ██╗       ║"
    echo "║       ██╔══██╗██║     ██╔════╝╚██╗██╔╝       ║"
    echo "║       ███████║██║     █████╗   ╚███╔╝        ║"
    echo "║       ██╔══██║██║     ██╔══╝   ██╔██╗        ║"
    echo "║       ██║  ██║███████╗███████╗██╔╝ ██╗       ║"
    echo "║       ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ║"
    echo "║          Alex ChatApp - One-Line Install     ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    [ "$EUID" -ne 0 ] && { echo "Run as root!"; exit 1; }
    echo "[i] Installing..."
    rm -rf /opt/chatapp
    git clone https://github.com/Alextaylorvhjnf/alex-chatapp-installer.git /opt/chatapp
    cd /opt/chatapp
    bash scripts/install.sh
    exit 0
fi

logo() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║        █████╗ ██╗     ███████╗██╗  ██╗       ║"
    echo "║       ██╔══██╗██║     ██╔════╝╚██╗██╔╝       ║"
    echo "║       ███████║██║     █████╗   ╚███╔╝        ║"
    echo "║       ██╔══██║██║     ██╔══╝   ██╔██╗        ║"
    echo "║       ██║  ██║███████╗███████╗██╔╝ ██╗       ║"
    echo "║       ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ║"
    echo "║          Alex ChatApp Installer              ║"
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

[ "$EUID" -ne 0 ] && { echo "Run as root!"; exit 1; }

while true; do
    clear
    logo
    system_info
    main_menu
    read -p "Select option: " choice
    case $choice in
        1) bash /opt/chatapp/scripts/install.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        2) bash /opt/chatapp/scripts/update.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        3) bash /opt/chatapp/scripts/backup.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        4) bash /opt/chatapp/scripts/cleanup.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        5) bash /opt/chatapp/scripts/status.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        6) bash /opt/chatapp/scripts/ssl.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        7) bash /opt/chatapp/scripts/admin.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        8) bash /opt/chatapp/scripts/security.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        9) bash /opt/chatapp/scripts/repair.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        10) bash /opt/chatapp/scripts/logs.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        11) bash /opt/chatapp/scripts/service.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        12) bash /opt/chatapp/scripts/database.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        13) bash /opt/chatapp/scripts/health.sh; read -s -n 1 -p "Press any key..." </dev/tty; echo ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid!"; sleep 1 ;;
    esac
done
