


<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/ubuntu-22.04%20%7C%2024.04-orange" alt="Ubuntu">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/docker-ready-brightgreen" alt="Docker">
</p>

<h1 align="center">Alex ChatApp</h1>
<p align="center">Self-Hosted Matrix Chat Platform — Deploy in Seconds</p>

<img src="https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/1.PNG">

---

## Quick Deploy

One command. Fully automated.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
```

---

## What You Get

- Matrix Synapse — Decentralized messaging server
- Element Web — Modern chat client
- PostgreSQL 16 — Database backend
- Nginx + Let's Encrypt — Auto HTTPS
- Docker Compose — Containerized management
- Health Monitoring — Built-in checks
- Auto Backups — Daily database backups
- UFW + Fail2Ban — Security

---

## Requirements

- Ubuntu 22.04 or 24.04
- Root access
- 2 Domain names pointed to server IP
- Ports 80 & 443 open

---

## DNS Setup

Create two A records pointing to your server IP:

```
chat.yourdomain.com   →  SERVER_IP
matrix.yourdomain.com →  SERVER_IP
```

**ChatApp Domain** = Browser interface for users

**Matrix Domain** = Server endpoint for mobile & desktop apps

---

## Installation

### Step 1 — Run

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
```

### Step 2 — Enter Domains

```
Enter ChatApp domain: chat.yourdomain.com
Enter Matrix domain: matrix.yourdomain.com
```

### Step 3 — Done

Open your browser:

```
https://chat.yourdomain.com
```

---

## Create Admin User

```bash
docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u admin -p YOUR_PASSWORD --admin
```

---

## Open Menu

```bash
cd /opt/chatapp && ./install.sh
```

Options:

- Install New ChatApp
- Update ChatApp
- Backup System
- Cleanup Media
- Server Status
- SSL Manager
- Admin Manager
- Security Manager
- Repair Manager
- Log Viewer
- Service Manager
- Database Manager
- Health Check

---

## Useful Commands

Check containers:

```bash
docker compose ps
```

View logs:

```bash
docker logs chatapp-synapse --tail 50
```

Restart:

```bash
docker compose restart
```

Manual backup:

```bash
bash /opt/chatapp/scripts/backup.sh
```

---

## Troubleshooting

SSL failed:

```bash
certbot --nginx -d chat.yourdomain.com -d matrix.yourdomain.com
```

Port conflict (stop Apache):

```bash
systemctl stop apache2
```

Postgres unhealthy:

```bash
rm -rf /opt/chatapp/postgres && docker compose up -d
```

---

## License

MIT © Alex Taylor
EOF

git add README.md
git commit -m "Clean professional README - separated code blocks"
git push origin main
```🚀
