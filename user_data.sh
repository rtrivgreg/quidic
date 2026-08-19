#!/bin/bash
# Prevent Ubuntu from popping up interactive prompt boxes mid-install
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Core System & Repository Updates ==="
apt-get update -y
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

echo "=== 2. Install Lightweight XFCE Desktop ==="
apt-get install -y xfce4 xfce4-goodies xinit xserver-xorg

echo "=== 3. Install Microsoft Remote Desktop Engine ==="
apt-get install -y xrdp
echo "xfce4-session" > /home/ubuntu/.xsession
chown ubuntu:ubuntu /home/ubuntu/.xsession
systemctl restart xrdp

echo "=== 4. Establish Default Password for Ubuntu Profile ==="
# Automatically sets your password to 'BlenderReady2026!' with zero typing required
echo "ubuntu:BlenderReady2026!" | chpasswd

echo "=== 5. Install Blender ==="
apt-get install -y blender

echo "=== 6. Silence the Color Management Popup Permanently ==="
mkdir -p /etc/polkit-1/localauthority/50-local.d/
cat << 'EOF' > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord Create Device]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device
ResultAny=yes
ResultInactive=yes
ResultActive=yes

[Allow Colord Create Profile]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-profile
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

echo "=== Infrastructure Build Complete ==="
