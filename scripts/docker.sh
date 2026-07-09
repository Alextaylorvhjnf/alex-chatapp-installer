#!/bin/bash

set -e


BASE_DIR="/opt/chatapp"



source $BASE_DIR/scripts/functions.sh



check_docker(){


    print_info "Checking Docker..."


    if command_exists docker; then

        print_ok "Docker installed"

    else

        print_warning "Docker not found. Installing..."


        curl -fsSL https://get.docker.com | sh


        systemctl enable docker

        systemctl start docker


        print_ok "Docker installed"

    fi


}



check_compose(){


    print_info "Checking Docker Compose..."


    if docker compose version >/dev/null 2>&1; then

        print_ok "Docker Compose plugin available"

        return

    fi



    if command_exists docker-compose; then

        print_ok "Legacy docker-compose available"

        return

    fi



    print_warning "Docker Compose not found"


    apt update


    apt install -y docker-compose



    print_ok "Docker Compose installed"


}



start_services(){


    print_info "Starting ChatApp containers..."


    cd $BASE_DIR


    if docker compose version >/dev/null 2>&1; then

        docker compose up -d

    else

        docker-compose up -d

    fi



    print_ok "Containers started"

}



stop_services(){


    print_info "Stopping ChatApp containers..."


    cd $BASE_DIR


    docker compose down


    print_ok "Containers stopped"


}



restart_services(){


    print_info "Restarting containers..."


    cd $BASE_DIR


    docker compose restart


    print_ok "Restart completed"

}



status_services(){


    echo

    echo "Docker Containers Status"

    echo "========================"


    docker ps \
    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"


}
