#!/usr/bin/env bash
# =============================================================================
# setup.sh — SOC Attack Detection Lab — Automated Setup
# =============================================================================
# Run this once before starting the lab.
# Usage: chmod +x setup.sh && sudo ./setup.sh

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
fail() { echo -e "${RED}[ FAIL ]${NC} $*"; exit 1; }

banner() {
  echo -e "\n${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║       SOC Attack Detection Lab — Setup          ║"
  echo "  ║   Wazuh + Suricata + Elastic + Kibana           ║"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Preflight checks ──────────────────────────────────────────────────────────
preflight() {
  log "Running preflight checks..."

  [[ "$EUID" -eq 0 ]] || fail "Please run as root (sudo ./setup.sh)"

  command -v docker      >/dev/null 2>&1 || fail "Docker not installed. Install from https://docs.docker.com/get-docker/"
  command -v docker-compose >/dev/null 2>&1 || \
  docker compose version >/dev/null 2>&1  || fail "Docker Compose not found."

  # Check available RAM (need at least 4GB for the full stack)
  total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  total_ram_gb=$((total_ram_kb / 1024 / 1024))
  if (( total_ram_gb < 4 )); then
    warn "Only ${total_ram_gb}GB RAM detected. Recommended: 6GB+. Performance may suffer."
  else
    ok "RAM: ${total_ram_gb}GB available"
  fi

  ok "Preflight checks passed"
}

# ── System tuning ─────────────────────────────────────────────────────────────
tune_system() {
  log "Applying system tuning for Elasticsearch..."

  # Elasticsearch requires vm.max_map_count >= 262144
  sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf

  # Disable swap for Elasticsearch performance
  swapoff -a

  ok "System tuning applied"
}

# ── Install attack tools in attacker container ────────────────────────────────
install_attack_tools() {
  log "Installing attack tools in Kali container..."

  docker exec attacker bash -c "
    apt-get update -qq &&
    apt-get install -y -qq \
      nmap hydra openssh-client netcat-openbsd curl wget \
      python3 python3-pip masscan hping3 2>/dev/null
  " && ok "Attack tools installed" || warn "Some tools may not have installed — attacker container may not be running yet"
}

# ── Kibana setup: create index patterns ──────────────────────────────────────
setup_kibana() {
  log "Waiting for Kibana to be ready..."
  local max_wait=120
  local waited=0

  until curl -s "http://localhost:5601/api/status" 2>/dev/null | grep -q "available"; do
    sleep 5
    waited=$((waited + 5))
    (( waited >= max_wait )) && { warn "Kibana not ready after ${max_wait}s — run setup_kibana manually"; return; }
    echo -n "."
  done
  echo ""

  log "Creating Kibana index patterns..."

  # Wazuh alerts index pattern
  curl -s -X POST "http://localhost:5601/api/saved_objects/index-pattern/wazuh-alerts-*" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"attributes":{"title":"wazuh-alerts-*","timeFieldName":"@timestamp"}}' \
    -u "elastic:SecretPassword1!" > /dev/null

  ok "Kibana index pattern created: wazuh-alerts-*"
}

# ── Generate self-signed TLS for Wazuh ───────────────────────────────────────
generate_certs() {
  log "Generating TLS certificates for Wazuh..."

  mkdir -p wazuh/certs
  cd wazuh/certs

  # Root CA
  openssl req -x509 -newkey rsa:4096 -keyout root-ca.key -out root-ca.pem \
    -days 365 -nodes -subj "/CN=SOC-Lab-CA/O=SOC-Lab" 2>/dev/null

  # Wazuh manager cert
  openssl req -newkey rsa:4096 -keyout wazuh-manager.key -out wazuh-manager.csr \
    -nodes -subj "/CN=wazuh-manager/O=SOC-Lab" 2>/dev/null
  openssl x509 -req -in wazuh-manager.csr -CA root-ca.pem -CAkey root-ca.key \
    -CAcreateserial -out wazuh-manager.pem -days 365 2>/dev/null

  # Filebeat cert
  openssl req -newkey rsa:4096 -keyout filebeat.key -out filebeat.csr \
    -nodes -subj "/CN=filebeat/O=SOC-Lab" 2>/dev/null
  openssl x509 -req -in filebeat.csr -CA root-ca.pem -CAkey root-ca.key \
    -CAcreateserial -out filebeat.pem -days 365 2>/dev/null

  cd ../..
  ok "TLS certificates generated"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  banner
  preflight
  tune_system
  generate_certs

  log "Starting SOC stack (this will take 3-5 minutes)..."
  docker-compose up -d --remove-orphans

  log "Waiting 60 seconds for services to initialize..."
  sleep 60

  install_attack_tools
  setup_kibana

  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║          SOC Lab is ready!                      ║"
  echo "  ╠══════════════════════════════════════════════════╣"
  echo "  ║  Kibana Dashboard  → http://localhost:5601      ║"
  echo "  ║  Username          → elastic                    ║"
  echo "  ║  Password          → SecretPassword1!           ║"
  echo "  ╠══════════════════════════════════════════════════╣"
  echo "  ║  Wazuh API         → https://localhost:55000    ║"
  echo "  ║  Username          → wazuh-wui                  ║"
  echo "  ║  Password          → MyS3cr3tP4ssw0rd*          ║"
  echo "  ╠══════════════════════════════════════════════════╣"
  echo "  ║  Run attacks:  ./attacks/ssh_bruteforce.sh      ║"
  echo "  ║  Run attacks:  ./attacks/port_scan.sh           ║"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

main "$@"
