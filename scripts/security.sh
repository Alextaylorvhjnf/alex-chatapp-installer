#!/bin/bash

set -e

BASE_DIR="/opt/chatapp"

source $BASE_DIR/scripts/functions.sh


clear

echo
echo "========================================"
echo "       Alex ChatApp Security Manager"
echo "========================================"
echo


require_root


echo

print_info "Installing security packages..."


apt update

apt install -y ufw fail2ban



print_ok "Packages installed"



echo

print_info "Configuring firewall..."



ufw --force reset


ufw default deny incoming
ufw default allow outgoing



# SSH
ufw allow 22/tcp


# HTTP HTTPS
ufw allow 80/tcp
ufw allow 443/tcp


# Matrix federation
ufw allow 8448/tcp



ufw --force enable



print_ok "Firewall enabled"



echo

print_info "Configuring Fail2Ban"



systemctl enable fail2ban
systemctl restart fail2ban



cat > /etc/fail2ban/jail.local <<EOF

[DEFAULT]

bantime = 1h
findtime = 10m
maxretry = 5


[sshd]

enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5


EOF



systemctl restart fail2ban



print_ok "Fail2Ban configured"



echo

echo "Security Status"
echo "---------------"


echo

echo "Firewall:"
ufw status


echo

echo "Fail2Ban:"
systemctl status fail2ban --no-pager | head -10



echo

echo "========================================"
echo " Security setup completed"
echo "========================================"
