#!/bin/bash

VERSION="1.0.0"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================
# Colors
# ==============================

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
MAGENTA="\033[0;35m"
GRAY="\033[0;37m"
NC="\033[0m"



# ==============================
# Load Modules
# ==============================

source "$BASE_DIR/scripts/functions.sh"


# ==============================
# Logo
# ==============================

logo(){

clear

echo -e "${CYAN}"

cat << "EOF"

╔══════════════════════════════════════════════╗
║                                              ║
║        █████╗ ██╗     ███████╗██╗  ██╗       ║
║       ██╔══██╗██║     ██╔════╝╚██╗██╔╝       ║
║       ███████║██║     █████╗   ╚███╔╝        ║
║       ██╔══██║██║     ██╔══╝   ██╔██╗        ║
║       ██║  ██║███████╗███████╗██╔╝ ██╗       ║
║       ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ║
║                                              ║
║          Alex ChatApp Installer              ║
║          Matrix + Synapse + Element          ║
║                                              ║
EOF

echo "║          Version: $VERSION                 ║"

cat << "EOF"
║                                              ║
╚══════════════════════════════════════════════╝

EOF

echo -e "${NC}"

}



# ==============================
# System Info
# ==============================

system_info(){

echo -e "${WHITE}"

echo "System Information"
echo "------------------"

echo "Hostname : $(hostname)"

echo "OS       : $(lsb_release -ds 2>/dev/null || echo Unknown)"

echo "CPU      : $(nproc) cores"

echo "RAM      : $(free -h | awk '/Mem:/ {print $2}')"

echo "Disk     : $(df -h / | awk 'NR==2 {print $4}') free"

echo

echo -e "${NC}"

}



# ==============================
# Menu
# ==============================

menu(){


echo -e "${CYAN}"

cat << EOF

╔══════════════════════════════════════════════╗
║                 MAIN MENU                    ║
╠══════════════════════════════════════════════╣
║                                              ║
║  1) 🚀 Install New ChatApp                   ║
║  2) 🔄 Update ChatApp                        ║
║  3) 💾 Backup System                         ║
║  4) 🧹 Cleanup Media                         ║
║  5) 📊 Server Status                         ║
║  6) 🔐 SSL Manager                           ║
║  7) 👤 Admin Manager                         ║
║  8) 🛡 Security Manager                      ║
║  9) 🛠 Repair Manager                        ║
║ 10) 📋 Log Viewer                            ║
║ 11) ⚙ Service Manager                        ║
║ 12) 🗄 Database Manager                      ║
║ 13) ❤️ Health Check                          ║
║                                              ║
║  0) Exit                                     ║
║                                              ║
╚══════════════════════════════════════════════╝

EOF

echo -e "${NC}"

}



# ==============================
# Execute Modules
# ==============================


run_script(){

FILE=$1


if [ -f "$BASE_DIR/scripts/$FILE" ]

then

bash "$BASE_DIR/scripts/$FILE"

else

echo -e "${RED}"
echo "Module missing:"
echo "$FILE"
echo -e "${NC}"

fi

read -p "Press Enter..."

}




# ==============================
# Main Loop
# ==============================


while true

do


logo

system_info

menu


read -r -p "Select option: " OPTION
OPTION=$(echo "$OPTION" | tr -d '[:space:]')


case "$OPTION" in


1)

run_script install.sh

;;


2)

run_script update.sh

;;


3)

run_script backup.sh

;;


4)

run_script cleanup.sh

;;


5)

run_script status.sh

;;


6)

run_script ssl.sh

;;


7)

run_script admin.sh

;;


8)

run_script security.sh

;;


9)

run_script repair.sh

;;


10)

run_script logs.sh

;;


11)

run_script service.sh

;;


12)

run_script database.sh

;;


13)

run_script health.sh

;;


0)

clear

echo

echo "Goodbye 👋"

exit 0

;;


*)

echo -e "${RED}Invalid option${NC}"

sleep 2

;;

esac


done
