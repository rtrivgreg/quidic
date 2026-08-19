#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Core System Updates ==="
apt-get update -y
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

echo "=== 2. Install Lightweight XFCE Desktop ==="
apt-get install -y xfce4 xfce4-goodies xinit xserver-xorg

echo "=== 3. Assemble and Download Browser Streaming Engine ==="
# Bypasses terminal pasting glitches by building the link locally
echo -n "https://d1uj6qtbmh3dt5" > link.txt
echo -n ".cloudfront.net/latest/" >> link.txt
echo "nice-dcv-ubuntu2204-x86_64.tgz" >> link.txt

wget -i link.txt -O dcv.tgz
tar -xvzf dcv.tgz
cd nice-dcv-*-ubuntu2204-x86_64

# Install the browser server modules
sudo apt-get install -y ./nice-dcv-server_*.ubuntu2204_amd64.deb ./nice-dcv-viewer_*.ubuntu2204_amd64.deb ./nice-xdcv_*.ubuntu2204_amd64.deb
sudo usermod -aG video dcv

echo "=== 4. Configure Browser User Account ==="
useradd -m -s /bin/bash dcvuser
echo "dcvuser:BlenderReady2026!" | chpasswd

echo "=== 5. Launch Browser Streaming Session ==="
systemctl enable dcvserver
systemctl start dcvserver
sudo dcv create-session --owner dcvuser --type virtual demo

echo "=== Browser Setup Complete ==="






