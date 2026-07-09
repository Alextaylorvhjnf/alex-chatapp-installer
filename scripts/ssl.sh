#!/bin/bash

set -e


BASE_DIR="/opt/chatapp"


source $BASE_DIR/scripts/functions.sh



clear


echo
echo "========================================"
echo "       Alex ChatApp SSL Manager"
echo "========================================"
echo



require_root


load_env



print_info "Checking required packages..."



apt update -y


apt install -y nginx certbot python3-certbot-nginx



print_ok "Packages ready"



# Validate domains

if [ -z "$CHAT_DOMAIN" ] || [ -z "$MATRIX_DOMAIN" ]; then

    echo "ERROR: Domain configuration missing"

    echo "Please run config manager first"

    exit 1

fi


# Remove old generated configs

rm -f /etc/nginx/sites-enabled/$CHAT_DOMAIN.conf
rm -f /etc/nginx/sites-enabled/$MATRIX_DOMAIN.conf


rm -f /etc/nginx/sites-available/$CHAT_DOMAIN.conf
rm -f /etc/nginx/sites-available/$MATRIX_DOMAIN.conf

# ------------------------------
# Generate nginx configs
# ------------------------------


print_info "Generating nginx configurations..."



replace_template \
$BASE_DIR/templates/nginx-chatapp.conf.tpl \
/etc/nginx/sites-available/$CHAT_DOMAIN.conf



replace_template \
$BASE_DIR/templates/nginx-matrix.conf.tpl \
/etc/nginx/sites-available/$MATRIX_DOMAIN.conf



print_ok "Nginx configs created"



# ------------------------------
# Enable sites
# ------------------------------


ln -sf \
/etc/nginx/sites-available/$CHAT_DOMAIN.conf \
/etc/nginx/sites-enabled/$CHAT_DOMAIN.conf



ln -sf \
/etc/nginx/sites-available/$MATRIX_DOMAIN.conf \
/etc/nginx/sites-enabled/$MATRIX_DOMAIN.conf



rm -f /etc/nginx/sites-enabled/default



# ------------------------------
# Test nginx
# ------------------------------


print_info "Testing nginx..."



nginx -t



systemctl enable nginx


systemctl restart nginx



print_ok "Nginx running"



# ------------------------------
# SSL
# ------------------------------


echo

print_info "Requesting SSL certificates..."



if certbot certificates | grep -q "$CHAT_DOMAIN"

then

print_ok "ChatApp SSL already exists"

else


certbot --nginx \
-d $CHAT_DOMAIN \
--non-interactive \
--agree-tos \
--register-unsafely-without-email


fi




if certbot certificates | grep -q "$MATRIX_DOMAIN"

then

print_ok "Matrix SSL already exists"

else


certbot --nginx \
-d $MATRIX_DOMAIN \
--non-interactive \
--agree-tos \
--register-unsafely-without-email


fi



# ------------------------------
# Renewal Test
# ------------------------------


print_info "Testing SSL renewal..."



certbot renew --dry-run



print_ok "SSL renewal configured"



systemctl reload nginx



echo


echo "========================================"

echo " SSL Setup Completed"

echo "========================================"


echo

echo "ChatApp:"
echo "https://$CHAT_DOMAIN"


echo

echo "Matrix:"
echo "https://$MATRIX_DOMAIN"


