# 3x-ui Traffic Exhaustion Watcher

A lightweight, automated Python service designed to solve an edge-case traffic exhaustion bug in 3x-ui multi-inbound setups.

## 🐛 The Problem

There is a known issue in 3x-ui regarding how traffic limits are enforced on multi-inbound setups. 

When a client with multiple inbounds connects exclusively to a remote node inbound and consumes all of their allocated traffic, the panel correctly marks the client as finished and disabled. However, **the local inbound does not stop**; it continues to work and accept connections despite being disabled in the UI.

### How this script fixes it
This script runs continuously in the background, monitoring the traffic usage of all clients. If it detects a client whose traffic has just crossed their limit (who wasn't previously exhausted), it automatically triggers an Xray service restart via the `/panel/api/server/restartXrayService` API. 

This forces the newly-disabled status to immediately take effect across all inbounds, instantly terminating active connections and preventing further unauthorized data usage.

## ✨ Features
- **Continuous Monitoring:** Automatically polls the 3x-ui panel API at a customizable interval (default: 30s).
- **Smart State Tracking:** Remembers clients who are already exhausted so it doesn't get caught in a restart loop. Only restarts Xray when a *new* exhaustion event occurs.
- **Systemd Integration:** Comes with an easy install script that wraps the monitor in a robust background systemd service.
- **Clean Environment:** Automatically sandboxes Python dependencies using `venv`.

## 🚀 Installation & Usage

### ⚡ Quick Install (One-liner)
You can directly install the watcher directly from GitHub by running this command on your server:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/bazarghan/3x-ui-watcher/main/xwatcher.sh)
```

### 🛠 Manual Install
Alternatively, you can clone or download this repository to your server.
1. Make the script executable and run it as root:
   ```bash
   chmod +x xwatcher.sh
   sudo ./xwatcher.sh
   ```

### Using the CLI (`xwatcher`)
The installation script features an interactive menu and will automatically install a global `xwatcher` command.
At any time, from anywhere on your server, simply type:

```bash
xwatcher
```

This will bring up the interactive color menu where you can:
- Install / Reinstall the watcher
- Enable & Start the service
- Disable & Stop the service
- View real-time logs
- Completely uninstall the watcher (removes all files and services)

## 🛠 Prerequisites
- A Linux server running systemd (Ubuntu, Debian, CentOS, etc.)
- Python 3 and `pip` (the installer will try to automatically install these on Ubuntu/Debian).

## 📄 License
MIT License
