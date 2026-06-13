#!/bin/bash

echo "=========================================="
echo "   3x-ui Traffic Monitor Installer"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g. using sudo ./install.sh)"
  exit 1
fi

read -p "Enter Panel Base URL (e.g. https://example.com/panel): " PANEL_URL
read -p "Enter API Token / Session Cookie (leave empty if none): " API_TOKEN
read -p "Enter check interval in seconds [default: 30]: " INTERVAL
INTERVAL=${INTERVAL:-30}

# Install dependencies on Debian/Ubuntu systems
if command -v apt &> /dev/null; then
    echo "[*] Installing Python3 and dependencies via apt..."
    apt-get update
    apt-get install -y python3 python3-pip python3-venv
fi

INSTALL_DIR="/opt/3xui-watcher"
echo "[*] Setting up directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Ensure monitor.py exists
if [ ! -f "monitor.py" ]; then
    echo "Error: monitor.py not found in the current directory!"
    exit 1
fi

cp monitor.py "$INSTALL_DIR/"

echo "[*] Setting up Python virtual environment..."
cd "$INSTALL_DIR" || exit 1
python3 -m venv venv
source venv/bin/activate
pip install requests

echo "[*] Creating systemd service..."
SERVICE_FILE="/etc/systemd/system/3xui-watcher.service"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=3x-ui Traffic Exhaustion Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/monitor.py --url "$PANEL_URL" --token "$API_TOKEN" --interval $INTERVAL
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Enabling and starting the service..."
systemctl daemon-reload
systemctl enable 3xui-watcher
systemctl restart 3xui-watcher

echo "=========================================="
echo " Installation complete!"
echo " Service '3xui-watcher' has been started and enabled on boot."
echo " To check the logs, run: journalctl -u 3xui-watcher -f"
echo " To stop the service, run: systemctl stop 3xui-watcher"
echo "=========================================="
