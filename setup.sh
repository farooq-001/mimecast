#!/bin/bash

set -euo pipefail

echo "🔐 Fill the API info:"

read -rp "APPLICATION-ID: " APPLICATION_ID
read -rp "APPLICATION-KEY: " APPLICATION_KEY
read -rp "ACCESS-KEY: " ACCESS_KEY
read -rp "SECRET-KEY: " SECRET_KEY
read -rp "EMAIL-ID: " EMAIL_ID

echo ""
echo "🔐 API info"
echo "APPLICATION-ID   : $APPLICATION_ID"
echo "APPLICATION-KEY  : $APPLICATION_KEY"
echo "ACCESS-KEY       : $ACCESS_KEY"
echo "SECRET-KEY       : $SECRET_KEY"
echo "EMAIL-ID         : $EMAIL_ID"

read -rp "Proceed with installation? (y/n): " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "❌ Installation cancelled."
    exit 1
fi

# Detect OS and install python3 + pip
if [[ -f /etc/redhat-release ]]; then
    echo "Detected RHEL/CentOS/Rocky Linux"
    yum install -y python3 python3-pip
elif [[ -f /etc/debian_version ]]; then
    echo "Detected Ubuntu/Debian"
    apt update
    apt install -y python3 python3-pip
else
    echo "Unsupported OS. Please install Python3 and pip manually."
    exit 1
fi

# Download and extract
cd /opt
wget -q https://prod1-us.blusapphire.net/export/install/beat/mimecast.tar.gz
tar -zxvf mimecast.tar.gz
rm -f mimecast.tar.gz

# Write config file
tee /opt/mimecast/mimecast.cnf > /dev/null <<EOF
[MIMECAST]
application_id = $APPLICATION_ID
application_key = $APPLICATION_KEY
access_key = $ACCESS_KEY
secret_key = $SECRET_KEY
URI = /api/audit/get-siem-logs
email_id = $EMAIL_ID

[LOG]
log_file = mimlog.log
log_level = INFO

[OUTPUT]
backup_file = /opt/mimecast/mimecast_backup.txt
host = 127.0.0.1
port = 12282
poolSize = 10

[REGISTRY]
file = /opt/mimecast/registry.txt

[INPUT]
msg_size = 60000
EOF


# Create systemd service
tee /etc/systemd/system/mimecastbeat.service > /dev/null <<EOF
[Unit]
Description=Mimecast Beat
After=network.target

[Service]
User=$(whoami)
Type=simple
WorkingDirectory=/opt/mimecast/
ExecStart=/usr/bin/python3 /opt/mimecast/mimecast.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start service
systemctl daemon-reload
systemctl enable mimecastbeat.service
systemctl start mimecastbeat.service

echo "✅ mimecastbeat service installed and started."
echo ""
echo "📤 ALogs are being sent on port 112283🎯"
