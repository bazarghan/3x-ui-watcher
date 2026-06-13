#!/bin/bash

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/3xui-watcher"
SERVICE_NAME="3xui-watcher.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
BIN_PATH="/usr/local/bin/xwatcher"

# Check root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root (e.g. using sudo bash $0)${NC}"
  exit 1
fi

function show_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${GREEN}      3x-ui Traffic Watcher (xwatcher)    ${NC}"
    echo -e "${CYAN}==========================================${NC}"
    
    # Check service status
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        echo -e "Status: ${GREEN}Active (Running)${NC}"
    elif [ -f "${SERVICE_FILE}" ]; then
        echo -e "Status: ${RED}Stopped / Disabled${NC}"
    else
        echo -e "Status: ${YELLOW}Not Installed${NC}"
    fi
    echo -e "${CYAN}------------------------------------------${NC}"
    
    echo "1) Install / Reinstall Watcher"
    echo "2) Uninstall Watcher"
    echo "3) Start & Enable Service"
    echo "4) Stop & Disable Service"
    echo "5) View Real-time Logs"
    echo "0) Exit"
    echo -e "${CYAN}------------------------------------------${NC}"
    read -p "Choose an option [0-5]: " OPTION
    
    case $OPTION in
        1) install_watcher ;;
        2) uninstall_watcher ;;
        3) start_service ;;
        4) stop_service ;;
        5) view_logs ;;
        0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 2; show_menu ;;
    esac
}

function install_watcher() {
    echo -e "\n${YELLOW}--- Installation ---${NC}"
    
    read -p "Enter Panel Base URL (e.g. https://example.com/panel): " PANEL_URL
    read -p "Enter API Token / Session Cookie (leave empty if none): " API_TOKEN
    read -p "Enter check interval in seconds [default: 30]: " INTERVAL
    INTERVAL=${INTERVAL:-30}

    # Install dependencies
    if command -v apt &> /dev/null; then
        echo -e "${CYAN}[*] Installing Python3 and dependencies via apt...${NC}"
        apt-get update -y > /dev/null 2>&1
        apt-get install -y python3 python3-pip python3-venv > /dev/null 2>&1
    fi

    echo -e "${CYAN}[*] Setting up directory at ${INSTALL_DIR}...${NC}"
    mkdir -p "${INSTALL_DIR}"

    # Ensure monitor.py exists
    if [ -f "monitor.py" ]; then
        cp monitor.py "${INSTALL_DIR}/"
    elif [ ! -f "${INSTALL_DIR}/monitor.py" ]; then
        echo -e "${RED}Error: monitor.py not found! Please run this script from the directory containing monitor.py${NC}"
        sleep 3
        show_menu
        return
    fi

    # Copy itself to /usr/local/bin so user can just type 'xwatcher'
    cp "$0" "${BIN_PATH}"
    chmod +x "${BIN_PATH}"

    echo -e "${CYAN}[*] Setting up Python virtual environment...${NC}"
    cd "${INSTALL_DIR}" || exit 1
    python3 -m venv venv
    source venv/bin/activate
    pip install requests > /dev/null 2>&1

    echo -e "${CYAN}[*] Creating systemd service...${NC}"
    cat <<EOF > "${SERVICE_FILE}"
[Unit]
Description=3x-ui Traffic Exhaustion Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python3 ${INSTALL_DIR}/monitor.py --url "${PANEL_URL}" --token "${API_TOKEN}" --interval ${INTERVAL}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME} > /dev/null 2>&1
    systemctl start ${SERVICE_NAME}

    echo -e "${GREEN}Installation complete!${NC}"
    echo -e "You can now manage the watcher anytime by typing: ${YELLOW}xwatcher${NC}"
    read -n 1 -s -r -p "Press any key to return to menu..."
    show_menu
}

function uninstall_watcher() {
    echo -e "\n${YELLOW}--- Uninstallation ---${NC}"
    read -p "Are you sure you want to completely remove the watcher? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}[*] Stopping service...${NC}"
        systemctl stop ${SERVICE_NAME} > /dev/null 2>&1
        systemctl disable ${SERVICE_NAME} > /dev/null 2>&1
        
        echo -e "${CYAN}[*] Removing files...${NC}"
        rm -f "${SERVICE_FILE}"
        systemctl daemon-reload
        
        rm -rf "${INSTALL_DIR}"
        rm -f "${BIN_PATH}"
        
        echo -e "${GREEN}Watcher has been completely uninstalled.${NC}"
        exit 0
    else
        echo -e "${CYAN}Uninstallation cancelled.${NC}"
        sleep 2
        show_menu
    fi
}

function start_service() {
    if [ -f "${SERVICE_FILE}" ]; then
        systemctl enable ${SERVICE_NAME} > /dev/null 2>&1
        systemctl start ${SERVICE_NAME}
        echo -e "${GREEN}Service Enabled and Started.${NC}"
    else
        echo -e "${RED}Watcher is not installed!${NC}"
    fi
    sleep 2
    show_menu
}

function stop_service() {
    if [ -f "${SERVICE_FILE}" ]; then
        systemctl stop ${SERVICE_NAME}
        systemctl disable ${SERVICE_NAME} > /dev/null 2>&1
        echo -e "${YELLOW}Service Stopped and Disabled.${NC}"
    else
        echo -e "${RED}Watcher is not installed!${NC}"
    fi
    sleep 2
    show_menu
}

function view_logs() {
    if [ -f "${SERVICE_FILE}" ]; then
        echo -e "${CYAN}Press Ctrl+C to exit logs.${NC}"
        sleep 2
        journalctl -u ${SERVICE_NAME} -f
    else
        echo -e "${RED}Watcher is not installed!${NC}"
        sleep 2
        show_menu
    fi
}

# Entry point
show_menu
