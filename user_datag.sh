#!/bin/bash
# Redirect all outputs to a log file so we can monitor setup progress later
exec > >(tee /var/log/user-data.log|logger -t user-data -s2>/dev/console) 2>&1

echo "=== System Core Updates ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y ubuntu-drivers-common build-essential

echo "=== Installing NVIDIA Gaming Drivers ==="
# Automatically downloads and sets up the AWS G5 graphics card drivers
ubuntu-drivers install --gpgpu
# Configures the graphics card to talk directly to the Linux display system
nvidia-xconfig --preserve-busid --allow-empty-initial-configuration

echo "=== Installing XFCE Visual Desktop ==="
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

echo "=== Installing Blender ==="
apt-get install -y blender

echo "=== Configuring GPU-Accelerated DCV Session ==="
systemctl enable dcvserver
systemctl start dcvserver

# Tells DCV to activate physical GPU hardware rendering for Blender
dcv create-session --owner dcvuser --type virtual --gl on demo

echo "=== All Done! Ready for 3D Modeling ==="

