version: "3.8"

services:

  postgres:
    image: postgres:16
    container_name: chatapp-postgres
    restart: always
    environment:
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: aA0922ny@
      POSTGRES_DB: synapse
      POSTGRES_INITDB_ARGS: "--locale=C --encoding=UTF8"
    volumes:
      - ./postgres:/var/lib/postgresql/data
    networks:
      - chatapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synapse"]
      interval: 10s
      timeout: 5s
      retries: 5


  synapse:
    image: matrixdotorg/synapse:v1.156.0
    container_name: chatapp-synapse
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8008:8008"
      - "8448:8448"
    volumes:
      - ./synapse:/data
    environment:
      - SYNAPSE_SERVER_NAME=matrix.shikpooshaan.ir
      - SYNAPSE_REPORT_STATS=no
    networks:
      - chatapp
    healthcheck:
      test: ["CMD-SHELL", "curl -fSs http://localhost:8008/health || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s


  element:
    image: vectorim/element-web:latest
    container_name: chatapp-element
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./element/config.json:/app/config.json
    networks:
      - chatapp
    healthcheck:
      test: ["CMD-SHELL", "curl -fSs http://localhost:80 || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 5


networks:
  chatapp:
    driver: bridge
