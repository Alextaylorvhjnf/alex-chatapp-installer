server {

    listen 80;

    server_name ${MATRIX_DOMAIN};


    location / {

        proxy_pass http://127.0.0.1:8008;

        proxy_http_version 1.1;


        proxy_set_header Host $host;

        proxy_set_header X-Real-IP $remote_addr;

        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_set_header X-Forwarded-Proto $scheme;


        client_max_body_size 100M;

        proxy_read_timeout 600;

        proxy_connect_timeout 600;

        proxy_send_timeout 600;

    }


    location /.well-known/matrix/client {

        default_type application/json;

        add_header Access-Control-Allow-Origin *;

        return 200 '{
            "m.homeserver": {
                "base_url": "https://${MATRIX_DOMAIN}"
            }
        }';

    }


    location /.well-known/matrix/server {

        default_type application/json;

        add_header Access-Control-Allow-Origin *;

        return 200 '{
            "m.server": "${MATRIX_DOMAIN}:443"
        }';

    }

}
