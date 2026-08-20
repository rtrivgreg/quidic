#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Install Pre-Compiled AWS NVIDIA Drivers ==="
apt-get update -y
# Installs matching development tools and kernel structures to prevent compilation crashes
apt-get install -y build-essential linux-headers-$(uname -r)

# Install pre-compiled, non-interactive NVIDIA drivers optimized for AWS servers
apt-get install -y nvidia-driver-535-server
nvidia-xconfig --preserve-busid --allow-empty-initial-configuration

echo "=== 2. Install Desktop Environment ==="
apt-get install -y xfce4 xfce4-goodies xinit xserver-xorg lightdm python3-psutil
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager

echo "=== 3. Fetch Installer ==="
echo -n "https://d1uj6qtbmh3dt5" > link.txt
echo -n ".cloudfront.net/latest/" >> link.txt
echo "nice-dcv-ubuntu2204-x86_64.tgz" >> link.txt
wget -i link.txt -O dcv.tgz
tar -xvzf dcv.tgz
cd nice-dcv-*-ubuntu2204-x86_64

echo "=== 4. Install DCV & HTML5 Web Viewer ==="
sudo apt-get install -y \
  ./nice-dcv-server_*.ubuntu2204_amd64.deb \
  ./nice-dcv-viewer_*.ubuntu2204_amd64.deb \
  ./nice-xdcv_*.ubuntu2204_amd64.deb \
  ./nice-dcv-web-viewer_*.ubuntu2204_amd64.deb
sudo usermod -aG video dcv
cd ..

echo "=== 5. Configure User Account ==="
useradd -m -s /bin/bash dcvuser
echo "dcvuser:BlenderReady2026!" | chpasswd

echo "=== 6. Configure dcv.conf for Browser Access ==="
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

echo "=== 7. Fire Up Hardware Daemons ==="
# NEW: Force-disable internal OS firewall blocks to clear local timeout locks
ufw disable
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
iptables -A INPUT -p udp --dport 8443 -j ACCEPT

systemctl enable lightdm && systemctl start lightdm
systemctl enable dcvserver && systemctl start dcvserver
sleep 5

# Spins up a Virtual Session with Full GPU Acceleration ON
sudo dcv create-session --owner dcvuser --type virtual --gl on demo


echo "=== 8. Install Blender ==="
apt-get install -y blender

echo "=== 9. Build Network-Aware Timeout Engine ==="
cat << 'EOF' > /usr/local/bin/autoshutdown.py
import sys
import time
import psutil
import subprocess

CHECK_INTERVAL = 60  # 1 minute
if len(sys.argv) < 2: sys.exit(1)
try:
    idle_time_ms = float(sys.argv[1])
    IDLE_TIME_SECS = idle_time_ms / 1000.0
except ValueError: sys.exit(1)

idle_start = None
while True:
    active = False
    for conn in psutil.net_connections(kind='tcp'):
        if conn.laddr.port == 8443 and conn.status == 'ESTABLISHED':
            active = True
            break
    if active:
        idle_start = None
    else:
        if idle_start is None:
            idle_start = time.time()
        elif time.time() - idle_start >= IDLE_TIME_SECS:
            subprocess.call(['shutdown', '-h', 'now'])
            break
    time.sleep(CHECK_INTERVAL)
EOF

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

systemctl daemon-reload
systemctl enable autoshutdown.service && systemctl start autoshutdown.service
