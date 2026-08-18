#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s2>/dev/console) 2>&1

echo "=== System Core Updates ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "=== Installing XFCE Visual Desktop Environment ==="
apt-get install -y xfce4 xfce4-goodies xinit xserver-xorg

# Create our desktop user account
useradd -m -s /bin/bash dcvuser
echo "dcvuser:BlenderReady2026!" | chpasswd

echo "=== Downloading & Installing NICE DCV Server ==="
wget https://cloudfront.net
gpg --import NICE-GPG-KEY
apt-key add NICE-GPG-KEY

wget https://cloudfront.net
tar -xvzf nice-dcv-2024.0-17239-ubuntu2204-x86_64.tgz
cd nice-dcv-2024.0-17239-ubuntu2204-x86_64

apt-get install -y ./nice-dcv-server_*.ubuntu2204_amd64.deb
apt-get install -y ./nice-dcv-viewer_*.ubuntu2204_amd64.deb
apt-get install -y ./nice-xdcv_*.ubuntu2204_amd64.deb
usermod -aG video dcv

echo "=== Installing Blender (CPU-Fallback Mode) ==="
apt-get install -y blender

echo "=== Configuring CPU-Optimized DCV Session ==="
systemctl enable dcvserver
systemctl start dcvserver

# FIXED: Dropped '--gl on' since this machine uses standard CPU processing
dcv create-session --owner dcvuser --type virtual demo

echo "=== All Done! Ready for Testing ==="








