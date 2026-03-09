#!/usr/bin/env bash
# =============================================================================
# attacks/port_scan.sh — Port Scan Attack Simulation
# =============================================================================
# Simulates multiple Nmap scan techniques to trigger Suricata IDS alerts.
# Each technique maps to a specific Suricata rule (SID 9000010-9000015).
#
# Usage:
#   ./attacks/port_scan.sh [TARGET_IP]
#   docker exec attacker bash /attacks/port_scan.sh 172.20.0.13
# =============================================================================

set -euo pipefail

TARGET_IP="${1:-172.20.0.13}"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${CYAN}[ATTACK]${NC} $*"; }
phase() { echo -e "\n${BOLD}${RED}━━━ $* ━━━${NC}"; }
info()  { echo -e "${YELLOW}[INFO  ]${NC} $*"; }
ok()    { echo -e "${GREEN}[DETECT]${NC} Expected alert: $*"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║    PORT SCAN ATTACK SIMULATION               ║"
echo "  ║    FOR EDUCATIONAL / SOC TRAINING USE ONLY   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Target : ${BOLD}${TARGET_IP}${NC}"
echo -e "  Time   : $(date)"
echo ""

# ── Dependency check ─────────────────────────────────────────────────────────
check_deps() {
  for tool in nmap masscan hping3; do
    command -v "$tool" &>/dev/null || {
      log "Installing $tool..."
      apt-get install -y -qq "$tool" 2>/dev/null || true
    }
  done
}

# ── Scan 1: SYN Scan (most common) ───────────────────────────────────────────
scan_syn() {
  phase "SCAN 1: TCP SYN Scan (nmap -sS)"
  info "Most common scan type. Sends SYN, never completes handshake."
  info "Suricata rule: SID 9000010"

  nmap -sS -p 1-1024 --open -T4 "${TARGET_IP}" 2>/dev/null || \
  nmap -sT -p 1-1024 --open -T4 "${TARGET_IP}" 2>/dev/null || true

  ok "SOC-LAB Nmap SYN Port Scan Detected (SID 9000010)"
  sleep 3
}

# ── Scan 2: NULL Scan ─────────────────────────────────────────────────────────
scan_null() {
  phase "SCAN 2: TCP NULL Scan (nmap -sN)"
  info "Sends TCP packets with no flags set. Used to bypass basic firewalls."
  info "Suricata rule: SID 9000011"

  nmap -sN -p 22,80,443,3306,8080 "${TARGET_IP}" 2>/dev/null || true

  ok "SOC-LAB Nmap NULL Scan Detected (SID 9000011)"
  sleep 3
}

# ── Scan 3: FIN Scan ──────────────────────────────────────────────────────────
scan_fin() {
  phase "SCAN 3: TCP FIN Scan (nmap -sF)"
  info "Sends TCP FIN packets. Closed ports respond with RST."
  info "Suricata rule: SID 9000012"

  nmap -sF -p 22,80,443,3306,8080 "${TARGET_IP}" 2>/dev/null || true

  ok "SOC-LAB Nmap FIN Scan Detected (SID 9000012)"
  sleep 3
}

# ── Scan 4: XMAS Scan ─────────────────────────────────────────────────────────
scan_xmas() {
  phase "SCAN 4: XMAS Scan (nmap -sX)"
  info "Sets FIN, PSH, URG flags — 'lights up like a Christmas tree'."
  info "Suricata rule: SID 9000013"

  nmap -sX -p 22,80,443,3306,8080 "${TARGET_IP}" 2>/dev/null || true

  ok "SOC-LAB Nmap XMAS Scan Detected (SID 9000013)"
  sleep 3
}

# ── Scan 5: UDP Scan ──────────────────────────────────────────────────────────
scan_udp() {
  phase "SCAN 5: UDP Scan (nmap -sU)"
  info "Scans UDP services: DNS (53), SNMP (161), DHCP (67/68)."
  info "Suricata rule: SID 9000014"

  nmap -sU -p 53,67,68,161,514 --open "${TARGET_IP}" 2>/dev/null || true

  ok "SOC-LAB UDP Port Scan Detected (SID 9000014)"
  sleep 3
}

# ── Scan 6: Aggressive OS fingerprinting ─────────────────────────────────────
scan_os_detect() {
  phase "SCAN 6: OS Detection & Service Versioning (nmap -A)"
  info "Full aggressive scan — OS detection, version detection, script scan."
  info "Generates the most SIEM alerts."

  nmap -A -p 22,80,443 "${TARGET_IP}" 2>/dev/null || true

  ok "Multiple Suricata rules triggered"
  sleep 3
}

# ── Scan 7: Fast full-port scan with masscan ──────────────────────────────────
scan_masscan() {
  phase "SCAN 7: High-Speed Full Port Scan (masscan)"
  info "Masscan — scans all 65535 ports at high speed."
  info "Triggers threshold-based Suricata alerts."

  masscan "${TARGET_IP}" -p 1-65535 --rate=1000 2>/dev/null || {
    log "masscan not available — using nmap full scan instead"
    nmap -p- --open -T4 "${TARGET_IP}" 2>/dev/null || true
  }

  ok "SSH Scanner alert triggered (SID 9000015)"
  sleep 3
}

# ── Scan 8: hping3 flood simulation ──────────────────────────────────────────
scan_hping() {
  phase "SCAN 8: TCP SYN Flood Simulation (hping3)"
  info "Sends crafted TCP packets rapidly — simulates DoS reconnaissance."

  # Short burst only — just enough to trigger detection
  timeout 10 hping3 -S --flood -V -p 80 "${TARGET_IP}" 2>/dev/null || \
  timeout 5  hping3 -S -c 100 -p 80 "${TARGET_IP}" 2>/dev/null || {
    log "hping3 not available — skipping"
    return
  }

  ok "High-volume SYN detected"
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║  Port scan simulation complete                      ║"
  echo "  ╠══════════════════════════════════════════════════════╣"
  echo "  ║  Expected Suricata Alerts:                          ║"
  echo "  ║    SID 9000010 — SYN Scan                          ║"
  echo "  ║    SID 9000011 — NULL Scan                         ║"
  echo "  ║    SID 9000012 — FIN Scan                          ║"
  echo "  ║    SID 9000013 — XMAS Scan                         ║"
  echo "  ║    SID 9000014 — UDP Scan                          ║"
  echo "  ║    SID 9000015 — OS Fingerprint                    ║"
  echo "  ╠══════════════════════════════════════════════════════╣"
  echo "  ║  View in Kibana: http://localhost:5601              ║"
  echo "  ║  Filter: event.module: suricata                     ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_deps

  log "Starting port scan simulation against ${TARGET_IP}"
  log "All traffic visible in Suricata EVE log and Kibana"
  echo ""

  scan_syn
  scan_null
  scan_fin
  scan_xmas
  scan_udp
  scan_os_detect
  scan_masscan
  scan_hping

  print_summary
}

main "$@"
