cd /opt/chatapp

cat > README.md << 'EOF'
<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/platform-Ubuntu%2022.04%20%7C%2024.04-orange?style=for-the-badge" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/docker-ready-brightgreen?style=for-the-badge" alt="Docker">
</p>

<h1 align="center">⚡ Alex ChatApp</h1>
<h3 align="center">Self-Hosted Matrix Chat Platform — Deploy in Seconds</h3>

<p align="center">
  A production-ready, fully automated installer for deploying your own<br>
  <strong>Matrix Synapse</strong> server with <strong>Element Web</strong> client.
</p>

---

## 🚀 Quick Deploy

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
That's it. One command. Fully automated.

✨ What You Get
Service	Description
🧠 Matrix Synapse	Decentralized messaging server
💬 Element Web	Modern, feature-rich chat client
🐘 PostgreSQL 16	Reliable database backend
🔒 Nginx + Let's Encrypt	Automatic HTTPS for both domains
🐳 Docker Compose	Containerized, easy management
📊 Health Monitoring	Built-in health checks
💾 Auto Backups	Daily database backups
🛡️ Security	UFW + Fail2Ban ready
📋 Prerequisites
Ubuntu 22.04 LTS or 24.04 LTS

Root access

2 Domain names pointed to your server IP

Ports 80 & 443 open

🌐 Domain Setup
Before installing, point both domains to your server:

text
Type: A
chat.yourdomain.com    →  YOUR_SERVER_IP
matrix.yourdomain.com  →  YOUR_SERVER_IP
What's the difference?
ChatApp Domain — Where users open the chat in their browser

Matrix Domain — Backend server for mobile & desktop apps

📖 Installation Guide
Step 1 — Run the installer
bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
Step 2 — Enter your domains
text
Enter ChatApp domain: chat.yourdomain.com
Enter Matrix domain: matrix.yourdomain.com
Step 3 — Wait & Enjoy
The script handles everything:

Installs Docker & Docker Compose

Deploys PostgreSQL, Synapse & Element

Configures Nginx reverse proxy

Obtains SSL certificates automatically

Step 4 — Open your browser
text
https://chat.yourdomain.com
Create an account and start chatting!

👑 Create Admin User
bash
docker exec chatapp-synapse register_new_matrix_user \
  http://localhost:8008 \
  -c /data/homeserver.yaml \
  -u admin \
  -p YOUR_PASSWORD \
  --admin
🎮 Menu Options
After installation, run the menu anytime:

bash
cd /opt/chatapp && ./install.sh
text
╔══════════════════════════════════════════════╗
║                 MAIN MENU                    ║
╠══════════════════════════════════════════════╣
║  1)  🚀 Install New ChatApp                  ║
║  2)  🔄 Update ChatApp                       ║
║  3)  💾 Backup System                        ║
║  4)  🧹 Cleanup Media                        ║
║  5)  📊 Server Status                        ║
║  6)  🔐 SSL Manager                          ║
║  7)  👤 Admin Manager                        ║
║  8)  🛡  Security Manager                     ║
║  9)  🛠  Repair Manager                       ║
║  10) 📋 Log Viewer                           ║
║  11) ⚙  Service Manager                       ║
║  12) 🗄  Database Manager                     ║
║  13) ❤️  Health Check                         ║
║  0)  Exit                                    ║
╚══════════════════════════════════════════════╝
📁 Project Structure
text
/opt/chatapp/
├── docker-compose.yml
├── synapse/
│   └── homeserver.yaml
├── element/
│   └── config.json
├── postgres/
├── scripts/
│   ├── install.sh
│   ├── backup.sh
│   ├── update.sh
│   └── ...
└── .env
🔧 Useful Commands
bash
# Check all containers
docker compose ps

# View logs
docker logs chatapp-synapse --tail 50

# Restart services
docker compose restart

# Manual backup
bash /opt/chatapp/scripts/backup.sh
🛟 Troubleshooting
Issue	Fix
SSL failed	Run: certbot --nginx -d chat.domain.com -d matrix.domain.com
Port conflict	Stop Apache: systemctl stop apache2
Postgres unhealthy	rm -rf /opt/chatapp/postgres && docker compose up -d
⭐ Support
If this project helped you, give it a star! ⭐

📄 License
MIT © Alex Taylor
EOF

git add README.md
git commit -m "Professional English README with badges and clean layout"
git push origin main
