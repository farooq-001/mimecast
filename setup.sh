#!/bin/bash

set -e

echo "🔐 Fill the API info:"

read -p "APPLICATION-ID: " APPLICATION_ID
read -p "APPLICATION-KEY: " APPLICATION_KEY
read -p "ACCESS-KEY: " ACCESS_KEY
read -p "SECRET-KEY: " SECRET_KEY
read -p "EMAIL-ID: " EMAIL_ID

echo ""
echo "🔐 API info"
echo "APPLICATION-ID   : $APPLICATION_ID"
echo "APPLICATION-KEY  : $APPLICATION_KEY"
echo "ACCESS-KEY       : $ACCESS_KEY"
echo "SECRET-KEY       : $SECRET_KEY"
echo "EMAIL-ID         : $EMAIL_ID"

read -p "Proceed with installation? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ Installation cancelled."
    exit 1
fi

# Detect OS and install python3 + pip
if [ -f /etc/redhat-release ]; then
    # Rocky, CentOS, RHEL family
    echo "Detected RHEL/CentOS/Rocky Linux"
    sudo yum install -y python3 python3-pip
elif [ -f /etc/debian_version ]; then
    # Ubuntu/Debian family
    echo "Detected Ubuntu/Debian"
    sudo apt update
    sudo apt install -y python3 python3-pip
else
    echo "Unsupported OS. Please install Python3 and pip manually."
    exit 1
fi

# Upgrade pip
python3 -m pip install --upgrade pip

# Create working directory
sudo mkdir -p /opt/mimecast
sudo chown "$(whoami)":"$(whoami)" /opt/mimecast

# Write config file
cat <<EOF > /opt/mimecast/mimecast.cnf
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

# Check if requirements.txt exists in current dir
if [[ ! -f requirements.txt ]]; then
    echo "requirements.txt not found in current directory."
    exit 1
fi

# Install python packages from requirements.txt
python3 -m pip install -r requirements.txt

# Create systemd service file
cat <<EOF | sudo tee /etc/systemd/system/mimecastbeat.service > /dev/null
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
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable mimecastbeat.service
sudo systemctl start mimecastbeat.service

echo "✅ mimecastbeat service installed and started."
