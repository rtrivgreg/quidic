#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Core System & Desktop Updates ==="
apt-get update -y
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

# Force install a display manager alongside XFCE to run the background monitor
apt-get install -y xfce4 xfce4-goodies xinit xserver-xorg lightdm python3-psutil
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager

echo "=== 2. Download and Extract Engine ==="
echo -n "https://d1uj6qtbmh3dt5" > link.txt
echo -n ".cloudfront.net/latest/" >> link.txt
echo "nice-dcv-ubuntu2204-x86_64.tgz" >> link.txt

wget -i link.txt -O dcv.tgz
tar -xvzf dcv.tgz
cd nice-dcv-*-ubuntu2204-x86_64

echo "=== 3. Install Server and Web Components ==="
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

echo "=== 5. Configure dcv.conf Bypass Properties ==="
# Force NICE DCV to allow browser authentication and loopback display rules
mkdir -p /etc/dcv/
cat << 'EOF' > /etc/dcv/dcv.conf
[security]
authentication="none"

[session-management]
create-session = true

[session-management/automatic-console-session]
owner = "dcvuser"

[connectivity]
web-port = 8443
EOF

echo "=== 6. Start Core Services ==="
systemctl enable lightdm
systemctl start lightdm
systemctl enable dcvserver
systemctl start dcvserver

# Let the display engines initialize cleanly
sleep 5
sudo dcv create-session --owner dcvuser --type virtual demo

echo "=== 7. Install Blender ==="
apt-get install -y blender

echo "=== 8. Create the Idle Shutdown Python Script ==="
cat << 'EOF' > /usr/local/bin/autoshutdown.py
import sys
import time
import psutil
import subprocess

CHECK_INTERVAL = 60  # 1 minute

if len(sys.argv) < 2:
    sys.exit(1)

try:
    idle_time_ms = float(sys.argv[0])
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

echo "=== 9. Create the Systemd Daemon with Terraform Variable ==="
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

echo "=== 10. Start Auto-Shutdown Service ==="
systemctl daemon-reload
systemctl enable autoshutdown.service
systemctl start autoshutdown.service

echo "=== Infrastructure Build Complete ==="
