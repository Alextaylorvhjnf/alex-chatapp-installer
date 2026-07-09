cd /opt/chatapp

cat > README.md << 'EOF'
# 🚀 Alex ChatApp Installer

<div align="center">

**⚡ One-Line Install | نصب با یک دستور ⚡**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
</div>
<div dir="rtl">
📱 نصب پیام‌رسان الکس
یک اسکریپت خودکار برای نصب کامل پیام‌رسان Matrix با امکانات زیر:

🐳 Docker	🔐 SSL خودکار	📊 مانیتورینگ	💾 پشتیبان‌گیری
⚡ نصب با یک دستور
bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
📋 نیازمندی‌ها
Ubuntu 22.04 یا 24.04

دسترسی root

دو دامنه با DNS تنظیم شده

🌐 تنظیم دامنه
قبل از نصب، دو رکورد A بسازید:

text
chat.YOURDOMAIN.com   →  Server_IP
matrix.YOURDOMAIN.com →  Server_IP
❓ دامنه چت و ماتریکس چه فرقی دارند؟
دامنه	کاربرد
ChatApp Domain	آدرس صفحه چت که کاربران می‌بینند
Matrix Domain	آدرس سرور برای اتصال اپلیکیشن‌ها
📝 مراحل نصب
۱. دستور تک خطی را اجرا کنید
۲. نام دامنه‌ها را وارد کنید
۳. منتظر بمانید تا نصب تمام شود
۴. مرورگر را باز کنید و آدرس دامنه چت را بزنید 🎉

👤 ساخت ادمین
bash
docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u admin -p YOUR_PASSWORD --admin
</div>
🚀 Alex ChatApp - One-Click Installer
Automated installer for a complete Matrix-based chat platform.

🐳 Docker	🔐 Auto SSL	📊 Monitoring	💾 Auto Backup
⚡ One Command Install
bash
bash <(curl -sSL https://raw.githubusercontent.com/Alextaylorvhjnf/alex-chatapp-installer/main/install.sh)
📋 Requirements
Ubuntu 22.04 or 24.04

Root access

Two domains with DNS pointed to server

🌐 DNS Configuration
Create two A records:

text
chat.YOURDOMAIN.com   →  Server_IP
matrix.YOURDOMAIN.com →  Server_IP
❓ ChatApp vs Matrix Domain?
Domain	Purpose
ChatApp Domain	Web interface users open in browser
Matrix Domain	Server endpoint for mobile & desktop apps
📝 Steps
Run the one-line command

Enter your domains

Wait for installation to complete

Open ChatApp domain in browser 🎉

👤 Create Admin User
bash
docker exec chatapp-synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u admin -p YOUR_PASSWORD --admin
🎯 Features | امکانات
Feature	Status
🔐 Auto SSL / SSL خودکار	✅
🐳 Docker Auto Install	✅
📊 Health Check / بررسی سلامت	✅
💾 Daily Backup / پشتیبان روزانه	✅
🔄 Easy Update / بروزرسانی آسان	✅
🛡 Fail2Ban + UFW	✅
📋 Log Viewer / نمایش لاگ	✅
📁 Structure | ساختار
text
/opt/chatapp/
├── docker-compose.yml
├── synapse/homeserver.yaml
├── element/config.json
├── postgres/
├── scripts/
│   ├── install.sh
│   ├── backup.sh
│   └── ...
└── .env
👨‍💻 Author | توسعه‌دهنده
Alex Taylor

GitHub: @Alextaylorvhjnf

📄 License | لایسنس
MIT - Free to use and modify
EOF

git add README.md
git commit -m "Bilingual README - no specific domains"
git push origin main
