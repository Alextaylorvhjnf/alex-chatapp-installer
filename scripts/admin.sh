#!/bin/bash

echo
echo "========================================"
echo "       Alex ChatApp Admin Manager"
echo "========================================"
echo
echo "1) Create normal user"
echo "2) Create admin user"  
echo "3) List all users"
echo "4) Show user details"
echo "5) Reset user password"
echo "6) Deactivate/Delete user"
echo "0) Back"
echo
echo -n "Select option: "
read opt

case $opt in
    0) exit 0 ;;
    
    3)
        echo
        docker exec chatapp-postgres psql -U synapse -d synapse -c "SELECT name, admin, deactivated FROM users ORDER BY name;" 2>/dev/null
        echo
        echo -n "Press Enter..."
        read
        ;;
        
    4)
        echo
        docker exec chatapp-postgres psql -U synapse -d synapse -c "SELECT name, admin, deactivated FROM users ORDER BY name;" 2>/dev/null
        echo
        echo -n "Press Enter..."
        read
        ;;
        
    5)
        echo
        echo "Select user to reset password:"
        echo "-------------------------------"
        
        mapfile -t users < <(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT name FROM users WHERE deactivated = 0 ORDER BY name;" 2>/dev/null | tr -d ' ' | grep -v '^$')
        
        for i in "${!users[@]}"; do
            echo "$((i+1))) ${users[$i]}"
        done
        echo "0) Cancel"
        echo
        echo -n "Select number: "
        read num
        
        [ "$num" = "0" ] && exit 0
        
        index=$((num-1))
        if [ -n "${users[$index]}" ]; then
            selected="${users[$index]}"
            echo
            echo "User: $selected"
            echo -n "New password: "
            read -s p
            echo
            
            if [ -z "$p" ]; then
                echo "Password required!"
            else
                username=$(echo "$selected" | sed 's/@.*//')
                is_admin=$(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT admin FROM users WHERE name = '$selected';" 2>/dev/null | tr -d ' ')
                
                admin_flag="--no-admin"
                [ "$is_admin" = "1" ] && admin_flag="--admin"
                
                echo "Resetting password..."
                echo -e "$p\n$p" | docker exec -i chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u "$username" -p "$p" $admin_flag 2>&1
                echo "Password reset complete!"
            fi
        fi
        echo
        echo -n "Press Enter..."
        read
        ;;
        
    6)
        echo
        echo "Select user to deactivate/delete:"
        echo "----------------------------------"
        
        mapfile -t users < <(docker exec chatapp-postgres psql -U synapse -d synapse -t -c "SELECT name FROM users ORDER BY name;" 2>/dev/null | tr -d ' ' | grep -v '^$')
        
        for i in "${!users[@]}"; do
            echo "$((i+1))) ${users[$i]}"
        done
        echo "0) Cancel"
        echo
        echo -n "Select number: "
        read num
        
        [ "$num" = "0" ] && exit 0
        
        index=$((num-1))
        if [ -n "${users[$index]}" ]; then
            selected="${users[$index]}"
            echo
            echo "User: $selected"
            echo "1) Deactivate"
            echo "2) Delete permanently"
            echo -n "Select: "
            read action
            
            if [ "$action" = "1" ]; then
                docker exec chatapp-postgres psql -U synapse -d synapse -c "UPDATE users SET deactivated = 1 WHERE name = '$selected';" 2>/dev/null
                echo "Deactivated!"
            elif [ "$action" = "2" ]; then
                docker exec chatapp-postgres psql -U synapse -d synapse -c "DELETE FROM users WHERE name = '$selected';" 2>/dev/null
                echo "Deleted!"
            fi
        fi
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
