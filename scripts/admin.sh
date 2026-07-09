#!/bin/bash

echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo
echo "1) Create normal user"
echo "2) Create admin user"  
echo "3) List all users"
echo "0) Back"
echo
echo -n "Select option: "
read opt

case $opt in
    0) exit 0 ;;
    3)
        docker exec chatapp-postgres psql -U synapse -d synapse -c "SELECT name, admin FROM users ORDER BY name;" 2>/dev/null
        echo
        echo -n "Press Enter..."
        read
        ;;
    1|2)
        echo
        echo -n "Username: "
        read u
        echo -n "Password: "
        read -s p
        echo
        
        if [ -z "$u" ] || [ -z "$p" ]; then
            echo "Username and password required!"
        else
            flag="--no-admin"
            [ "$opt" = "2" ] && flag="--admin"
            docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$u" -p "$p" $flag 2>&1
            echo
            echo "Done! @${u}:matrix.shikpooshaan.ir"
        fi
        echo
        echo -n "Press Enter..."
        read
        ;;
esac
