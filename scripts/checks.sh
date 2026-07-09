#!/bin/bash

BASE_DIR="/opt/chatapp"

source $BASE_DIR/scripts/functions.sh


show_system_info(){


clear


echo
echo "========================================"
echo "        Alex ChatApp System Check"
echo "========================================"
echo


HOSTNAME=$(hostname)

OS=$(lsb_release -ds 2>/dev/null || echo "Unknown")

CPU=$(nproc)

RAM=$(free -h | awk '/Mem:/ {print $2}')

DISK=$(df -h / | awk 'NR==2 {print $4}')



echo "System Information"
echo "------------------"

echo

echo "Hostname : $HOSTNAME"

echo "OS       : $OS"

echo "CPU      : $CPU cores"

echo "RAM      : $RAM"

echo "Disk     : $DISK free"


echo


}



check_docker_status(){


echo

echo "Docker Status"

echo "-------------"


if command_exists docker; then


    print_ok "Docker installed"


    docker --version


else

    print_error "Docker missing"

fi


}



check_containers(){


echo

echo "Containers"

echo "----------"


if command_exists docker; then


docker ps \
--format "table {{.Names}}\t{{.Status}}"


else

echo "Docker unavailable"

fi



}



check_ports(){


echo

echo "Network Ports"

echo "-------------"


PORTS=(80 443 8008 8448 8080)


for PORT in "${PORTS[@]}"
do


if ss -tuln | grep -q ":$PORT "; then

    echo -e "$PORT : ${GREEN}OPEN${NC}"

else

    echo -e "$PORT : ${RED}CLOSED${NC}"

fi


done


}



full_check(){


show_system_info

check_docker_status

check_containers

check_ports



echo

read -p "Press Enter to return..."

}
