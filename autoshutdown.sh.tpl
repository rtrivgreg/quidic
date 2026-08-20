#!/bin/bash

# 1. Install dependencies
apt-get update -y
apt-get install -y python3-psutil

# 2. Create the Python script file
# Single quotes ('EOF') here are CORRECT because we want to preserve Python's native strings.
cat << 'EOF' > /usr/local/bin/autoshutdown.py
import sys
import time
import psutil
import subprocess

CHECK_INTERVAL = 60  # 1 minute

if len(sys.argv) < 2:
    sys.exit(1)

try:
    idle_time_ms = float(sys.argv[1])
    IDLE_TIME_SECS = idle_time_ms / 1000.0
except ValueError:
    sys.exit(1)

time.sleep(3)
idle_start = None

def is_system_active():
    if psutil.users():
        return True
    return False

while True:
    if is_system_active():
        idle_start = None
    else:
        if idle_start is None:
            idle_start = time.time()
        elif time.time() - idle_start >= IDLE_TIME_SECS:
            subprocess.call(['sudo', 'shutdown', '-h', 'now'])
            break
    time.sleep(CHECK_INTERVAL)
EOF

# 3. Create the systemd service file using the Terraform variable injection
# CRITICAL FIX: Removed single quotes around EOF to allow Terraform variable substitution.
cat << EOF > /etc/systemd/system/autoshutdown.service
[Unit]
Description=Auto Shutdown EC2 on Idle
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/autoshutdown.py ${idle_timeout_ms}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 4. Load, enable, and start the background process
systemctl daemon-reload
systemctl enable autoshutdown.service
systemctl start autoshutdown.service
