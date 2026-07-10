#!/bin/bash


clear


echo
echo "========================================"
echo "       Alex ChatApp Health Check"
echo "========================================"
echo


echo "[Docker]"

docker ps


echo


echo "[Nginx]"

nginx -t


echo


echo "[SSL]"

certbot certificates | grep Expiry


echo


echo "[Disk]"

df -h /


echo


echo "[Memory]"

free -h


echo


echo "[Ports]"

ss -tulpn | grep -E "80|443|8008|8448"


echo

echo "Health Check Completed"

read -s -n 1 -p "Press any key to return..." </dev/tty; echo
