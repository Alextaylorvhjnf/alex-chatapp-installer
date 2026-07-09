# 🚀 Alex ChatApp Installer

A professional interactive installer for deploying a complete self-hosted Matrix chat platform.

This installer automatically deploys:

- Matrix Synapse Server
- Element Web Client
- PostgreSQL
- Nginx Reverse Proxy
- Let's Encrypt SSL
- Docker & Docker Compose integration
- Automatic Backup Manager
- Automatic Update Manager
- Health Check
- Security Manager
- Repair Manager
- Service Manager
- Database Manager
- Log Viewer
- Media Cleanup

---

# Features

- Interactive CLI interface
- Colored terminal UI
- Automatic SSL installation
- Automatic Nginx configuration
- Automatic Docker deployment
- Automatic backups
- Automatic updates
- Health monitoring
- Repair utilities
- Firewall configuration
- Fail2Ban integration
- Matrix federation support
- Easy maintenance

---

# Requirements

- Ubuntu 22.04 LTS or newer
- Root access
- Public IPv4
- Docker
- Docker Compose
- Domain name

---

# Domain Configuration

The installer asks for two domains.

## Chat Domain

Example:

```
chat.example.com
```

This domain hosts the Element Web Client.

Users open this address in their browser to access the chat interface.

Example:

```
https://chat.example.com
```

---

## Matrix Domain

Example:

```
matrix.example.com
```

This domain hosts the Matrix Synapse server.

It is used for:

- Matrix Client API
- Federation
- Server-to-server communication
- Mobile applications
- Desktop applications

Example:

```
https://matrix.example.com
```

---

# DNS Records

Create two A records.

```
chat.example.com
        ↓
Server IP

matrix.example.com
        ↓
Server IP
```

Wait until DNS propagation is complete before requesting SSL certificates.

---

# Installation

Clone the repository

```bash
git clone https://github.com/Alextaylorvhjnf/alex-chatapp-installer.git

cd alex-chatapp-installer
```

Make installer executable

```bash
chmod +x install.sh
```

Run

```bash
./install.sh
```

---

# Main Menu

```
1  Install ChatApp
2  Update
3  Backup
4  Cleanup Media
5  Server Status
6  SSL Manager
7  Admin Manager
8  Security Manager
9  Repair Manager
10 Log Viewer
11 Service Manager
12 Database Manager
13 Health Check
```

---

# Configuration

The installer stores configuration in

```
/opt/chatapp/.env
```

Example

```
CHAT_DOMAIN=chat.example.com

MATRIX_DOMAIN=matrix.example.com

MEDIA_RETENTION_DAYS=10

BACKUP_RETENTION_DAYS=7
```

---

# SSL

SSL certificates are automatically installed using Let's Encrypt.

Certificates are automatically renewed by Certbot.

---

# Project Structure

```
alex-chatapp-installer/

├── install.sh
├── update.sh
├── backup.sh
├── docker-compose.yml
├── scripts/
│   ├── install.sh
│   ├── update.sh
│   ├── backup.sh
│   ├── cleanup.sh
│   ├── service.sh
│   ├── repair.sh
│   ├── health.sh
│   ├── security.sh
│   ├── ssl.sh
│   ├── admin.sh
│   ├── logs.sh
│   ├── database.sh
│   ├── functions.sh
│   ├── docker.sh
│   └── checks.sh
│
├── templates/
│   ├── homeserver.yaml.tpl
│   ├── docker-compose.yml.tpl
│   ├── element-config.json.tpl
│   ├── nginx-chatapp.conf.tpl
│   └── nginx-matrix.conf.tpl
```

---

# Backup

Backups include:

- PostgreSQL
- Synapse configuration
- Element configuration

Backups are stored in

```
/opt/chatapp/backups
```

---

# Health Check

The Health Manager verifies:

- Docker
- Containers
- Disk usage
- Memory usage
- SSL certificates
- Open ports
- Nginx
- Synapse

---

# Security

Security Manager configures:

- UFW Firewall
- Fail2Ban
- Secure SSH
- Matrix ports
- HTTPS ports

---

# Matrix Federation

Port

```
8448
```

must remain open if federation is enabled.

---

# Useful Links

Matrix

https://matrix.org/

Synapse Documentation

https://matrix-org.github.io/synapse/latest/

Element

https://element.io/

Docker

https://docs.docker.com/

Let's Encrypt

https://letsencrypt.org/

Nginx

https://nginx.org/

---

# License

MIT License

---

# Author

Alex Taylor

GitHub

https://github.com/Alextaylorvhjnf
