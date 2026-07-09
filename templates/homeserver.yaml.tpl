server_name: "matrix.shikpooshaan.ir"

pid_file: /data/homeserver.pid

listeners:
  - port: 8008
    type: http
    tls: false
    x_forwarded: true
    bind_addresses:
      - 0.0.0.0
    resources:
      - names:
          - client
          - federation
        compress: false

database:
  name: psycopg2
  args:
    user: synapse
    password: "aA0922ny@"
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

log_config: "/data/matrix.shikpooshaan.ir.log.config"

media_store_path: /data/media_store

registration_shared_secret: "aA0922ny@"

report_stats: false

macaroon_secret_key: "aA0922ny@"

form_secret: "aA0922ny@"

signing_key_path: "/data/matrix.shikpooshaan.ir.signing.key"

trusted_key_servers:
  - server_name: "matrix.org"

enable_registration: true
enable_registration_without_verification: true

max_upload_size: 500M
