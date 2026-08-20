#!/usr/bin/env bash
# Amazon DCV setup for an NVIDIA RTX Virtual Workstation Marketplace AMI (vGPU 20.2)
# on a g5.xlarge. The NVIDIA driver is preinstalled and licensed by AWS on this
# AMI, so this script deliberately does NOT touch the GPU driver.
#
# Idempotent: safe to re-run. Run as a normal sudo-capable user (e.g. ubuntu).
#   chmod +x install-dcv.sh && ./install-dcv.sh
set -euo pipefail

log() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!! %s\033[0m\n' "$*"; }
die() { printf '\033[31mXX %s\033[0m\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
log "Preflight"
# --------------------------------------------------------------------------
. /etc/os-release
echo "OS: ${PRETTY_NAME}"
case "${VERSION_ID:-}" in
  22.04) DIST=ubuntu2204 ;;
  24.04) DIST=ubuntu2404 ;;
  20.04) DIST=ubuntu2004 ;;
  *) die "Unhandled OS ${PRETTY_NAME}. Check the DCV download page for a matching package set." ;;
esac
[ "$(uname -m)" = "x86_64" ] || die "Expected x86_64 on g5.xlarge, got $(uname -m)."

# GPU driver comes with the AMI; verify rather than install.
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
  nvidia-smi -q | grep -i -m1 -A2 "vGPU Software Licensed Product" || true
else
  die "nvidia-smi not working. Fix the preinstalled driver before installing DCV; do NOT layer the AWS GRID driver on this AMI."
fi

# DCV license check needs IMDS; a missing instance profile is the #1 failure.
TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300" || true)
ROLE=$(curl -sf -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/ || true)
if [ -z "${ROLE}" ]; then
  warn "No IAM instance profile visible from IMDS. DCV will fall back to the 30-day"
  warn "evaluation license and will stop creating sessions when it expires."
  warn "Attach DCVLicProfile, then re-run this script."
else
  echo "Instance profile role: ${ROLE}"
fi

# --------------------------------------------------------------------------
log "Desktop environment and display manager"
# --------------------------------------------------------------------------
sudo apt-get update -qq
if ! dpkg -l ubuntu-desktop >/dev/null 2>&1 && [ ! -x /usr/sbin/gdm3 ]; then
  echo "No desktop detected; installing ubuntu-desktop (this takes a few minutes)."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop gdm3
else
  echo "Desktop environment already present."
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dkms pulseaudio-utils mesa-utils

# DCV cannot attach to a Wayland session.
if [ -f /etc/gdm3/custom.conf ]; then
  if grep -qE '^\s*WaylandEnable\s*=\s*false' /etc/gdm3/custom.conf; then
    echo "Wayland already disabled."
  else
    sudo sed -i 's/^#\?\s*WaylandEnable\s*=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
    grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf \
      || sudo sed -i '/^\[daemon\]/a WaylandEnable=false' /etc/gdm3/custom.conf
    echo "Disabled Wayland in /etc/gdm3/custom.conf."
    NEED_X_RESTART=1
  fi
fi

# --------------------------------------------------------------------------
log "X server"
# --------------------------------------------------------------------------
if [ "$(sudo systemctl get-default)" != "graphical.target" ]; then
  sudo systemctl set-default graphical.target
  NEED_X_RESTART=1
fi

# Only generate xorg.conf if the AMI did not ship one — do not clobber NVIDIA's.
if [ -f /etc/X11/xorg.conf ]; then
  echo "/etc/X11/xorg.conf already present; leaving it alone."
else
  sudo rm -rf /etc/X11/XF86Config*
  sudo nvidia-xconfig --preserve-busid --enable-all-gpus
  NEED_X_RESTART=1
fi

if [ "${NEED_X_RESTART:-0}" = "1" ]; then
  echo "Restarting the graphical target."
  sudo systemctl isolate multi-user.target
  sleep 3
  sudo systemctl isolate graphical.target
  sleep 8
fi
ps aux | grep -q '[X]org' && echo "Xorg is running." || warn "Xorg is not running; console sessions will show a black screen."

# --------------------------------------------------------------------------
log "Amazon DCV server"
# --------------------------------------------------------------------------
if command -v dcv >/dev/null 2>&1; then
  echo "DCV already installed: $(dcv version 2>/dev/null | head -1)"
else
  WORK=$(mktemp -d)
  cd "$WORK"
  curl -fsSLO https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
  gpg --import NICE-GPG-KEY
  curl -fsSLO "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-${DIST}-x86_64.tgz"
  tar -xzf "nice-dcv-${DIST}-x86_64.tgz"
  cd nice-dcv-*-"${DIST}"-x86_64
  # gl provides GPU sharing + glxinfo; xdcv provides virtual sessions
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ./nice-dcv-server_*.deb ./nice-dcv-web-viewer_*.deb ./nice-xdcv_*.deb
  if ls ./nice-dcv-gl_*.deb >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ./nice-dcv-gl_*.deb
  else
    warn "No nice-dcv-gl package for ${DIST}; GPU sharing for virtual sessions unavailable."
  fi
  sudo dcvusbdriverinstaller --quiet || warn "USB driver install skipped."
fi

sudo usermod -aG video dcv
sudo systemctl enable --now dcvserver
sleep 5
systemctl is-active --quiet dcvserver && echo "dcvserver active." || die "dcvserver failed: sudo journalctl -u dcvserver -n 50"

# --------------------------------------------------------------------------
log "Session"
# --------------------------------------------------------------------------
SESSION_USER="${SUDO_USER:-$USER}"
if ! sudo passwd -S "$SESSION_USER" 2>/dev/null | awk '{print $2}' | grep -q '^P$'; then
  warn "User ${SESSION_USER} has no password set — DCV auth will fail."
  warn "Run: sudo passwd ${SESSION_USER}"
fi
if sudo dcv list-sessions | grep -q "my-session"; then
  echo "Session 'my-session' already exists."
else
  sudo dcv create-session --owner "$SESSION_USER" --user "$SESSION_USER" --type console my-session
fi
sudo dcv list-sessions

PUB=$(curl -sf -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/public-ipv4 || echo "<public-ip>")
log "Connect at https://${PUB}:8443/#my-session"
echo "Self-signed cert warning is expected. If it hangs, check 8443 TCP *and* UDP ingress."
echo "Verify hardware OpenGL inside the session with: glxinfo | grep -i 'opengl.*version'"
