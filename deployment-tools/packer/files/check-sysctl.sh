#!/usr/bin/env bash
# check-rtp-sysctl.sh
# Read-only inspection of kernel UDP/socket buffer config & runtime health for RTP/FreeSWITCH.

set -euo pipefail

AUDIT=0
[[ "${1:-}" == "--audit" ]] && AUDIT=1

# ---------- Recommended floors/ceilings you want to audit against ----------
REC_UDP_RMEM_MIN=262144     # 256 KB
REC_UDP_WMEM_MIN=262144     # 256 KB
REC_RMEM_DEFAULT=2097152    # 2 MB
REC_WMEM_DEFAULT=2097152    # 2 MB
REC_RMEM_MAX=8388608        # 8 MB
REC_WMEM_MAX=8388608        # 8 MB
REC_NETDEV_MAX_BACKLOG=5000 # optional, only relevant if softnet drops show up

# ---------- helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }
val() { sysctl -n "$1" 2>/dev/null || echo "N/A"; }
cmp_ge() { [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]] && (( $1 >= $2 )); }
sep() { printf "\n==== %s ====\n" "$1"; }

check() {
  local name="$1" cur="$2" rec="$3"
  if [[ $AUDIT -eq 0 || "$cur" == "N/A" || ! "$rec" =~ ^[0-9]+$ ]]; then
    printf "  %-26s = %s\n" "$name" "$cur"
    return
  fi
  if cmp_ge "$cur" "$rec"; then
    printf "  %-26s = %-12s  [OK  >= %s]\n" "$name" "$cur" "$rec"
  else
    printf "  %-26s = %-12s  [WARN: < %s]\n" "$name" "$cur" "$rec"
  fi
}

# ---------- 1) Kernel sysctls (UDP/socket buffers) ----------
sep "Kernel socket/UDP buffer sysctls"
RMEM_DEF=$(val net.core.rmem_default)
RMEM_MAX=$(val net.core.rmem_max)
WMEM_DEF=$(val net.core.wmem_default)
WMEM_MAX=$(val net.core.wmem_max)
UDP_MEM=$(val net.ipv4.udp_mem)            # triplet
UDP_RMEM_MIN=$(val net.ipv4.udp_rmem_min)
UDP_WMEM_MIN=$(val net.ipv4.udp_wmem_min)
NETDEV_MAX_BACKLOG=$(val net.core.netdev_max_backlog)

check "net.core.rmem_default" "$RMEM_DEF" "$REC_RMEM_DEFAULT"
check "net.core.rmem_max"     "$RMEM_MAX" "$REC_RMEM_MAX"
check "net.core.wmem_default" "$WMEM_DEF" "$REC_WMEM_DEFAULT"
check "net.core.wmem_max"     "$WMEM_MAX" "$REC_WMEM_MAX"
check "net.ipv4.udp_rmem_min" "$UDP_RMEM_MIN" "$REC_UDP_RMEM_MIN"
check "net.ipv4.udp_wmem_min" "$UDP_WMEM_MIN" "$REC_UDP_WMEM_MIN"
printf "  %-26s = %s (system-wide UDP memory triplet)\n" "net.ipv4.udp_mem" "$UDP_MEM"
check "net.core.netdev_max_backlog" "$NETDEV_MAX_BACKLOG" "$REC_NETDEV_MAX_BACKLOG"

# ---------- 2) Live UDP error counters (since boot) ----------
sep "UDP error counters (since boot)"
if have nstat; then
  printf "  %-18s  %-12s  %-6s\n" "Name" "Value" "Rate"
  nstat -az | egrep 'Udp(InErrors|RcvbufErrors)' || true
else
  echo "  nstat not found; using /proc fallback"
  printf "  %-18s  %-12s\n" "Name" "Value"
  awk '
    /^Udp:/{
      if (!hdr){ hdr=$0; getline; val=$0;
        split(hdr,a); split(val,b);
        for(i=1;i<=length(a);i++){ if(a[i]=="InErrors") inerr=b[i]; if(a[i]=="RcvbufErrors") rcverr=b[i] }
        printf "  %-18s  %-12s\n","UdpInErrors",inerr;
        printf "  %-18s  %-12s\n","UdpRcvbufErrors",rcverr;
        exit
      }
    }' /proc/net/snmp
fi

# ---------- 3) Softnet health (drops/backlog pressure) ----------
sep "/proc/net/softnet_stat (per-CPU): col2=drops col3=time_squeeze"
awk '{drops+=$2; squeeze+=$3} END{printf "  total_drops=%d  total_timesqueeze=%d\n",drops,squeeze}' /proc/net/softnet_stat

# ---------- 6) NIC ring sizes (optional but useful) ----------
sep "NIC ring sizes (RX/TX) (requires ethtool)"
if have ethtool; then
  for IF in $(ls /sys/class/net | grep -vE '^(lo|docker|veth|br-|cni|flannel)'); do
    echo "  [$IF]"
    sudo ethtool -g "$IF" 2>/dev/null | sed 's/^/    /' || echo "    (no ring info)"
  done
else
  echo "  ethtool not installed."
fi

# ---------- 7) OS & kernel (context) ----------
sep "System context"
echo "  Hostname: $(hostname)"
echo "  Kernel:   $(uname -r)"
echo "  Distro:   $(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"' || echo N/A)"
