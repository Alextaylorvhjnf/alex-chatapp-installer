#!/bin/bash

BASE_DIR="/opt/chatapp"

source $BASE_DIR/scripts/functions.sh


clear


echo
echo "========================================"
echo "       Alex ChatApp Server Status"
echo "========================================"
echo


HOST=$(hostname)

OS=$(lsb_release -ds 2>/dev/null || echo "Unknown")

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8"%"}')


RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')

RAM_USED=$(free -h | awk '/Mem:/ {print $3}')


DISK=$(df -h / | awk 'NR==2 {print $4" free"}')



echo
echo "System Information"
echo "------------------"

echo "Hostname : $HOST"
echo "OS       : $OS"
echo "CPU      : $CPU"
echo "RAM      : $RAM_USED / $RAM_TOTAL"
echo "Disk     : $DISK"


echo
echo "Docker Services"
echo "---------------"


if docker ps >/dev/null 2>&1
then

docker ps \
--format "table {{.Names}}\t{{.Status}}"

else

echo "Docker unavailable"

fi



echo
echo "SSL Certificates"
echo "----------------"


if command -v certbot >/dev/null
then

certbot certificates 2>/dev/null | \
grep -E "Certificate Name|Expiry Date"

else

echo "Certbot not installed"

fi



echo
echo "========================================"

echo "Status check completed"

echo "========================================"

echo
