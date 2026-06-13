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

To install the watcher as a background systemd service on your Linux server (Debian/Ubuntu):

1. Clone or download this repository to your server.
2. Make the installer executable and run it as root:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```
3. The installer will prompt you for three pieces of information:
   - **Panel Base URL:** The full URL to your panel (e.g. `https://example.com:54321/webBasePath`).
   - **API Token / Session Cookie:** Your 3x-ui session token (leave blank if not required).
   - **Check Interval:** How often to check for traffic limits in seconds (default is 30).

### Managing the Service

Once installed, the service runs automatically in the background and will restart on server reboots. You can manage it using standard `systemctl` commands:

- **Check status / logs in real-time:**
  ```bash
  journalctl -u 3xui-watcher -f
  ```
- **Stop the watcher:**
  ```bash
  sudo systemctl stop 3xui-watcher
  ```
- **Start the watcher:**
  ```bash
  sudo systemctl start 3xui-watcher
  ```

## 🛠 Prerequisites
- A Linux server running systemd (Ubuntu, Debian, CentOS, etc.)
- Python 3 and `pip` (the installer will try to automatically install these on Ubuntu/Debian).

## 📄 License
MIT License
