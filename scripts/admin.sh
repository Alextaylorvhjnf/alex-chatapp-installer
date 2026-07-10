#!/bin/bash

clear
echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo
echo "1) Create normal user"
echo "2) Create admin user"  
echo "3) List all users"
echo "4) Reset user password"
echo "5) Deactivate user"
echo "6) Delete user (kick + remove)"
echo "0) Back"
echo
echo -n "Select option: "
read opt

case $opt in
    0) clear; exit 0 ;;
    
    3)
        echo
        docker exec chatapp-postgres psql -U synapse -d synapse -c "SELECT name, admin, deactivated FROM users ORDER BY name;" 2>/dev/null
        ;;
        
    4)
        echo
        echo "Select user:"
        mapfile -t users < <(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT name FROM users WHERE deactivated = 0 ORDER BY name;" 2>/dev/null | tr -d ' ' | grep -v '^$')
        for i in "${!users[@]}"; do echo "$((i+1))) ${users[$i]}"; done
        echo "0) Cancel"
        echo -n "Number: "
        read num
        [ "$num" = "0" ] && { clear; exit 0; }
        index=$((num-1))
        if [ -n "${users[$index]}" ]; then
            selected="${users[$index]}"
            echo -n "New password: "
            read -s p
            echo
            [ -n "$p" ] && username=$(echo "$selected" | sed 's/@.*//') && is_admin=$(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT admin FROM users WHERE name = '$selected';" 2>/dev/null | tr -d ' ') && admin_flag="--no-admin" && [ "$is_admin" = "1" ] && admin_flag="--admin" && echo -e "$p\n$p" | docker exec -i chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$username" -p "$p" $admin_flag 2>&1 && echo "Done!"
        fi
        ;;
        
    5)
        echo
        echo "Select user to deactivate:"
        mapfile -t users < <(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT name FROM users WHERE deactivated = 0 ORDER BY name;" 2>/dev/null | tr -d ' ' | grep -v '^$')
        for i in "${!users[@]}"; do echo "$((i+1))) ${users[$i]}"; done
        echo "0) Cancel"
        echo -n "Number: "
        read num
        [ "$num" = "0" ] && { clear; exit 0; }
        index=$((num-1))
        if [ -n "${users[$index]}" ]; then
            selected="${users[$index]}"
            docker exec chatapp-postgres psql -U synapse -d synapse -c "UPDATE users SET deactivated = 1 WHERE name = '$selected'; DELETE FROM access_tokens WHERE user_id = '$selected';" 2>/dev/null
            echo "$selected deactivated & kicked!"
        fi
        ;;
        
    6)
        echo
        echo "WARNING: Permanent delete!"
        mapfile -t users < <(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT name FROM users ORDER BY name;" 2>/dev/null | tr -d ' ' | grep -v '^$')
        for i in "${!users[@]}"; do echo "$((i+1))) ${users[$i]}"; done
        echo "0) Cancel"
        echo -n "Number: "
        read num
        [ "$num" = "0" ] && { clear; exit 0; }
        index=$((num-1))
        if [ -n "${users[$index]}" ]; then
            selected="${users[$index]}"
            echo -n "Type 'yes' to confirm: "
            read confirm
            [ "$confirm" = "yes" ] && docker exec chatapp-postgres psql -U synapse -d synapse -c "DELETE FROM access_tokens WHERE user_id = '$selected'; DELETE FROM refresh_tokens WHERE user_id = '$selected'; DELETE FROM users WHERE name = '$selected';" 2>/dev/null && echo "$selected deleted!"
        fi
        ;;
        
    1|2)
        echo -n "Username: "
        read u
        echo -n "Password: "
        read -s p
        echo
        flag="--no-admin"
        [ "$opt" = "2" ] && flag="--admin"
        [ -n "$u" ] && [ -n "$p" ] && docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$u" -p "$p" $flag 2>&1 && echo "Done! @${u}:matrix.shikpooshaan.ir"
        ;;
esac

echo
read -s -n 1 -p "Press any key to return..." </dev/tty
echo
clear
