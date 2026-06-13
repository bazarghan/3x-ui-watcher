import os
import time
import requests
import argparse
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def get_clients(base_url, headers):
    url = f"{base_url}/panel/api/clients/list"
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        if not data.get('success'):
            logging.error(f"API Error: {data.get('msg')}")
            return []
        return data.get('obj', [])
    except Exception as e:
        logging.error(f"Failed to fetch clients: {e}")
        return []

def restart_xray(base_url, headers):
    url = f"{base_url}/panel/api/server/restartXrayService"
    try:
        logging.info("Restarting Xray service...")
        # Since it is a POST with no parameters according to the prompt
        response = requests.post(url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        if data.get('success'):
            logging.info("Xray service restarted successfully.")
        else:
            logging.error(f"Failed to restart Xray: {data.get('msg')}")
    except Exception as e:
        logging.error(f"Error restarting Xray: {e}")

def main():
    parser = argparse.ArgumentParser(description="3x-ui Traffic Exhaustion Monitor")
    parser.add_argument('--url', required=True, help="Panel Base URL (e.g. https://ip:port/basePath)")
    parser.add_argument('--token', default="", help="API Token or Session Cookie")
    parser.add_argument('--interval', type=int, default=30, help="Check interval in seconds")
    
    args = parser.parse_args()
    
    base_url = args.url.rstrip('/')
    
    headers = {
        'Accept': 'application/json'
    }
    if args.token:
        # Cover both Bearer token auth and Cookie session auth depending on the panel fork
        headers['Authorization'] = f"Bearer {args.token}"
        headers['Cookie'] = f"session={args.token}"

    logging.info(f"Starting monitor on {base_url} every {args.interval} seconds.")
    
    # Keep track of users who are ALREADY exhausted
    exhausted_users = set()
    
    logging.info("Performing initial state sync...")
    initial_clients = get_clients(base_url, headers)
    
    for client in initial_clients:
        client_id = client.get('email', str(client.get('id', '')))
        if not client_id:
            continue
            
        total_gb = client.get('totalGB', 0)
        
        # Traffic properties could be flat or nested
        traffic = client.get('traffic', {})
        up = traffic.get('up', client.get('up', 0))
        down = traffic.get('down', client.get('down', 0))
        
        if total_gb > 0 and (up + down) >= total_gb:
            exhausted_users.add(client_id)
            
    logging.info(f"Initial sync complete. {len(exhausted_users)} users are currently exhausted.")

    while True:
        time.sleep(args.interval)
        try:
            clients = get_clients(base_url, headers)
            if not clients:
                continue
                
            should_restart = False
            current_exhausted = set()
            
            for client in clients:
                client_id = client.get('email', str(client.get('id', '')))
                if not client_id:
                    continue
                    
                total_gb = client.get('totalGB', 0)
                traffic = client.get('traffic', {})
                up = traffic.get('up', client.get('up', 0))
                down = traffic.get('down', client.get('down', 0))
                
                # Check if traffic is exhausted
                if total_gb > 0 and (up + down) >= total_gb:
                    current_exhausted.add(client_id)
                    # If this is a newly exhausted user, trigger restart
                    if client_id not in exhausted_users:
                        logging.info(f"User {client_id} just exhausted their traffic (Usage: {up+down} / {total_gb}).")
                        should_restart = True
                
            # Update state with the new list of exhausted users
            exhausted_users = current_exhausted
            
            if should_restart:
                restart_xray(base_url, headers)
                
        except Exception as e:
            logging.error(f"Unexpected error in main loop: {e}")

if __name__ == "__main__":
    main()
