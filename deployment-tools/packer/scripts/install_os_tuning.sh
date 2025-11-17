#!/bin/bash
# install_os_tuning.sh
# Usage: ./install_os_tuning.sh <VARIANT> <DISTRO>
# Applies OS/network tuning suitable for RTP-heavy FreeSWITCH workloads.

set -euo pipefail

VARIANT=${1:-}
DISTRO=${2:-}

export PATH=/usr/local/bin:$PATH

sudo cp /tmp/check-sysctl.sh /usr/local/bin/
sudo chmod a+x /usr/local/bin/check-sysctl.sh

# ---------- File descriptor limits ----------
sudo sed -i '/# End of file/i *                hard       nofile          65535'  /etc/security/limits.conf
sudo sed -i '/# End of file/i *                soft       nofile          65535'  /etc/security/limits.conf
sudo sed -i '/# End of file/i root             hard       nofile          65535'  /etc/security/limits.conf
sudo sed -i '/# End of file/i root             soft       nofile          65535'  /etc/security/limits.conf
# Systemd default
sudo sed -i 's/^#\?DefaultLimitNOFILE=.*$/DefaultLimitNOFILE=65535:65535/' /etc/systemd/system.conf || true

# ---------- Keep general sysctls in /etc/sysctl.conf (no rmem/wmem here) ----------
sudo bash -c 'cat >> /etc/sysctl.conf << "EOT"
net.ipv4.ip_default_ttl = 128
vm.swappiness = 0
vm.dirty_expire_centisecs = 200
vm.dirty_writeback_centisecs = 100
EOT'

# ---------- RTP/UDP socket buffer policy in a dedicated sysctl.d file ----------
# These allow the application to request larger buffers and set sane defaults.
sudo tee /etc/sysctl.d/90-rtp-buffers.conf >/dev/null <<'EOF'
# RTP/UDP socket buffer sizing for high-concurrency media workloads

# Per-socket UDP floors (critical to avoid tiny 4KB buffers under burst)
net.ipv4.udp_rmem_min = 262144
net.ipv4.udp_wmem_min = 262144

# Global per-socket defaults
net.core.rmem_default = 2097152
net.core.wmem_default = 2097152

# Global per-socket ceilings
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608

# Optional: only raise if you later observe softnet drops/backlog pressure
# net.core.netdev_max_backlog = 5000
EOF

# ---------- Distro-specific settings ----------
if [[ "$DISTRO" == rhel* ]] ; then
  # Enable core dumps
  grep -q "* soft core unlimited" /etc/security/limits.conf || echo "* soft core unlimited" | sudo tee -a /etc/security/limits.conf >/dev/null
  grep -q "* hard core unlimited" /etc/security/limits.conf || echo "* hard core unlimited" | sudo tee -a /etc/security/limits.conf >/dev/null
  ulimit -c unlimited
else
  # Debian/Ubuntu: auto-upgrades config if provided by Packer
  if [[ -f /tmp/20auto-upgrades ]]; then
    sudo cp /tmp/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades
  fi
fi

# ---------- Disable IPv6 (kept from original script) ----------
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf >/dev/null
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf >/dev/null

# ---------- RHEL firewall handling (kept) ----------
if [[ "$DISTRO" == rhel* ]] ; then
  echo "disable RHEL firewall"
  sudo systemctl stop firewalld || true
  sudo systemctl disable firewalld || true
fi

# ---------- Load sysctl settings ----------
sudo sysctl --system

sudo /usr/local/bin/check-sysctl.sh --audit
