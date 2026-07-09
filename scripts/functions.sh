#!/bin/bash


# ==========================================
# Alex ChatApp - Functions Library
# ==========================================


# Colors

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
GRAY="\033[0;37m"
NC="\033[0m"



# ==========================================
# Messages
# ==========================================


print_ok(){

echo -e "${GREEN}[✔]${NC} $1"

}



print_error(){

echo -e "${RED}[✘]${NC} $1"

}



print_warning(){

echo -e "${YELLOW}[!]${NC} $1"

}



print_info(){

echo -e "${CYAN}[i]${NC} $1"

}




# ==========================================
# Root Check
# ==========================================


require_root(){

if [ "$EUID" -ne 0 ]; then

    print_error "Please run as root"

    exit 1

fi

}



# ==========================================
# Command Check
# ==========================================


command_exists(){

command -v "$1" >/dev/null 2>&1

}



# ==========================================
# Loading Spinner
# ==========================================


spinner(){

PID=$1


spin='-\|/'


while kill -0 $PID 2>/dev/null

do


for i in $(seq 0 3)

do


printf "\r${CYAN}[${spin:$i:1}] Working...${NC}"


sleep .1


done


done


printf "\r"

}




# ==========================================
# Progress Bar
# ==========================================


progress(){

local duration=$1


echo


for ((i=0;i<=100;i+=5))

do


printf "\r["


printf "%${i}s" | tr ' ' '='


printf "%$((100-i))s" | tr ' ' ' '


printf "] %d%%" "$i"


sleep $duration


done


echo


}




# ==========================================
# Load Environment
# ==========================================


load_env(){

ENV_FILE="/opt/chatapp/.env"


if [ -f "$ENV_FILE" ]

then

    source "$ENV_FILE"

fi


}




# ==========================================
# Backup Directory
# ==========================================


create_backup_dir(){

mkdir -p /opt/chatapp/backups

}



# ==========================================
# Logging
# ==========================================


LOG_FILE="/var/log/alex-chatapp.log"



log(){

echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE

}

replace_template()
{
    TEMPLATE=$1
    OUTPUT=$2

    if [ ! -f "$TEMPLATE" ]
    then
        echo "Template not found: $TEMPLATE"
        exit 1
    fi


    cp "$TEMPLATE" "$OUTPUT"


    sed -i \
    -e "s|\${CHAT_DOMAIN}|${CHAT_DOMAIN}|g" \
    -e "s|\${MATRIX_DOMAIN}|${MATRIX_DOMAIN}|g" \
    "$OUTPUT"
}
