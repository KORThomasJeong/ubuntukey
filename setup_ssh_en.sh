#!/bin/bash

# SSH Key Generation and Download Script
# Usage: ./setup_ssh.sh [key_name] [port] [timeout]

set -e

# Default values
KEY_NAME=${1:-"id_rsa"}
PORT=${2:-8000}
TIMEOUT=${3:-300}  # 5 minutes timeout

echo "=== SSH Key Generation and Download Server Setup ==="
echo "Key name: $KEY_NAME"
echo "Port: $PORT"
echo "Timeout: ${TIMEOUT} seconds"
echo

# Check and install SSH
if ! command -v ssh &> /dev/null; then
    echo "SSH is not installed. Starting installation..."
    sudo apt update
    sudo apt install -y openssh-server openssh-client
    echo "SSH installation completed!"
else
    echo "SSH is already installed."
fi

# Check Python3 installation
if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed. Starting installation..."
    sudo apt update
    sudo apt install -y python3
    echo "Python3 installation completed!"
fi

# Create SSH directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Check if key already exists
if [[ -f ~/.ssh/$KEY_NAME ]]; then
    echo "Warning: SSH key ~/.ssh/$KEY_NAME already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

# Generate SSH key
echo "Generating SSH key..."
ssh-keygen -t rsa -b 4096 -f ~/.ssh/$KEY_NAME -N "" -C "$(whoami)@$(hostname)"
echo "SSH key generation completed!"

# Add public key to authorized_keys
if [[ -f ~/.ssh/$KEY_NAME.pub ]]; then
    cat ~/.ssh/$KEY_NAME.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "Public key added to authorized_keys."
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Temporary directory: $TEMP_DIR"

# Copy key files to temporary directory
cp ~/.ssh/$KEY_NAME $TEMP_DIR/
cp ~/.ssh/$KEY_NAME.pub $TEMP_DIR/

# Start SSH service
echo "Starting SSH service..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Get current IP addresses
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unavailable")

echo
echo "=== Server Information ==="
echo "Local IP: $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"
echo "SSH Port: 22"
echo

# Check if port is already in use
if netstat -tuln | grep ":$PORT " > /dev/null; then
    echo "Warning: Port $PORT is already in use."
    echo "Please use a different port or terminate the existing process."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm -rf $TEMP_DIR
        exit 1
    fi
fi

# Create Python server script
cat > $TEMP_DIR/server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
import signal
import threading
import time

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {format % args}")
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

def signal_handler(signum, frame):
    print(f"\nReceived signal {signum}. Shutting down server...")
    os._exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
timeout = int(sys.argv[2]) if len(sys.argv) > 2 else 300

print(f"Starting HTTP server on port {port}...")
print(f"Server will auto-shutdown after {timeout} seconds.")

with socketserver.TCPServer(("", port), CustomHTTPRequestHandler) as httpd:
    def shutdown_server():
        time.sleep(timeout)
        print(f"\nTimeout reached ({timeout} seconds). Shutting down server...")
        httpd.shutdown()
    
    timer = threading.Thread(target=shutdown_server)
    timer.daemon = True
    timer.start()
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer interrupted by user.")
    finally:
        httpd.server_close()
EOF

chmod +x $TEMP_DIR/server.py

# Create download guide page
cat > $TEMP_DIR/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSH Key Download</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .key-info { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .download-link { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; margin: 5px; }
        .download-link:hover { background: #0056b3; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 5px; margin: 10px 0; }
        .command { background: #f8f9fa; padding: 10px; border-left: 4px solid #007bff; margin: 10px 0; font-family: monospace; }
    </style>
</head>
<body>
    <h1>SSH Key Download</h1>
    
    <div class="warning">
        <strong>⚠️ Security Warning:</strong>
        <ul>
            <li>Never share your private key with others</li>
            <li>Shutdown this server immediately after downloading</li>
            <li>Set private key file permissions to 600</li>
        </ul>
    </div>

    <div class="key-info">
        <h3>Generated Key Information</h3>
        <p><strong>Key Name:</strong> $KEY_NAME</p>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Host:</strong> $(whoami)@$(hostname)</p>
    </div>

    <h3>Download</h3>
    <a href="$KEY_NAME" class="download-link" download>🔑 Download Private Key ($KEY_NAME)</a>
    <a href="$KEY_NAME.pub" class="download-link" download>🔓 Download Public Key ($KEY_NAME.pub)</a>

    <h3>Usage Instructions</h3>
    <div class="command">
        # Download keys (from another machine)<br>
        wget http://$LOCAL_IP:$PORT/$KEY_NAME<br>
        wget http://$LOCAL_IP:$PORT/$KEY_NAME.pub<br><br>
        
        # Or use curl<br>
        curl -O http://$LOCAL_IP:$PORT/$KEY_NAME<br>
        curl -O http://$LOCAL_IP:$PORT/$KEY_NAME.pub<br><br>
        
        # Set permissions<br>
        chmod 600 $KEY_NAME<br>
        chmod 644 $KEY_NAME.pub<br><br>
        
        # SSH connection<br>
        ssh -i $KEY_NAME $(whoami)@$LOCAL_IP
    </div>

    <p><small>This server will automatically shutdown after ${TIMEOUT} seconds.</small></p>
</body>
</html>
EOF

echo
echo "=== File Download Server Starting ==="
echo "Download URLs:"
echo "  - Private Key: http://$LOCAL_IP:$PORT/$KEY_NAME"
echo "  - Public Key: http://$LOCAL_IP:$PORT/$KEY_NAME.pub"
echo "  - Web Interface: http://$LOCAL_IP:$PORT/"
echo
echo "Download commands for other machines:"
echo "  wget http://$LOCAL_IP:$PORT/$KEY_NAME"
echo "  wget http://$LOCAL_IP:$PORT/$KEY_NAME.pub"
echo
echo "Server will auto-shutdown after ${TIMEOUT} seconds."
echo "Press Ctrl+C to shutdown manually."
echo

# Start server
cd $TEMP_DIR
python3 server.py $PORT $TIMEOUT

# Cleanup
echo
echo "Server shutdown. Cleaning up temporary files..."
cd /
rm -rf $TEMP_DIR

echo
echo "=== Completed ==="
echo "SSH key saved to ~/.ssh/$KEY_NAME"
echo "SSH service is running."
echo
echo "Connection test:"
echo "  ssh $(whoami)@localhost"
echo "  ssh -i ~/.ssh/$KEY_NAME $(whoami)@$LOCAL_IP"
echo
