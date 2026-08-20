#!/bin/bash
# Prevent interactive prompt blocks
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Core System & Repository Updates ==="
apt-get update -y
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

echo "=== 2. Install Lightweight XFCE Desktop ==="
apt-get install -y xfce4 xfce4-goodies xinit xserver-xorg python3-psutil

echo "=== 3. Download and Install Browser Streaming Engine ==="
# Bypasses paste buffer bugs by building the download path locally
echo -n "https://d1uj6qtbmh3dt5" > link.txt
echo -n ".cloudfront.net/latest/" >> link.txt
echo "nice-dcv-ubuntu2204-x86_64.tgz" >> link.txt

wget -i link.txt -O dcv.tgz
tar -xvzf dcv.tgz
cd nice-dcv-*-ubuntu2204-x86_64

# FIXED: Added the explicit web-viewer package to the auto-installer array
sudo apt-get install -y \
  ./nice-dcv-server_*.ubuntu2204_amd64.deb \
  ./nice-dcv-viewer_*.ubuntu2204_amd64.deb \
  ./nice-xdcv_*.ubuntu2204_amd64.deb \
  ./nice-dcv-web-viewer_*.ubuntu2204_amd64.deb

sudo usermod -aG video dcv
cd ..

echo "=== 4. Configure Browser User Account ==="
useradd -m -s /bin/bash dcvuser
echo "dcvuser:BlenderReady2026!" | chpasswd

echo "=== 5. Install Blender ==="
apt-get install -y blender

echo "=== 6. Launch Browser Streaming Session ==="
systemctl enable dcvserver
systemctl start dcvserver
sudo dcv create-session --owner dcvuser --type virtual demo

echo "=== 7. Create the Idle Shutdown Python Script ==="
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
    # Monitors active HTML5 browser sockets on port 8443
    for conn in psutil.net_connections(kind='tcp'):
        if conn.laddr.port == 8443 and conn.status == 'ESTABLISHED':
            return True
    return False

while True:
    if is_system_active():
        idle_start = None
    else:
        if idle_start is None:
            idle_start = time.time()
        elif time.time() - idle_start >= IDLE_TIME_SECS:
            subprocess.call(['shutdown', '-h', 'now'])
            break
    time.sleep(CHECK_INTERVAL)
EOF

echo "=== 8. Create the Systemd Daemon with Terraform Variable ==="
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

echo "=== 9. Start Auto-Shutdown Service ==="
systemctl daemon-reload
systemctl enable autoshutdown.service
systemctl start autoshutdown.service

echo "=== Infrastructure Build Complete ==="
