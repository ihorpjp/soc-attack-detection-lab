# 🛡️ SOC Attack Detection Lab

A production-quality mini Security Operations Center (SOC) environment built with Docker Compose. Simulates real cyberattacks and detects them using Wazuh SIEM, Suricata IDS, and the Elastic Stack — with a full Kibana dashboard.

> **Built for:** Cybersecurity students, SOC analysts, and IT professionals learning threat detection in a safe, controlled environment.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Network: 172.20.0.0/24                │
│                                                                  │
│  ┌─────────────────┐          ┌──────────────────────────────┐  │
│  │  ATTACKER        │          │  MONITORING STACK            │  │
│  │  172.20.0.99     │          │                              │  │
│  │  Kali Linux      │─attack──▶│  Wazuh SIEM   172.20.0.12   │  │
│  │  · nmap          │          │  Suricata IDS (host net)     │  │
│  │  · hydra         │          │  Elasticsearch 172.20.0.10   │  │
│  │  · hping3        │          │  Kibana        172.20.0.11   │  │
│  └─────────────────┘          └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Detection layers:**

| Layer | Tool | Detects |
|---|---|---|
| Host-based IDS | Wazuh | Failed logins, sudo abuse, file integrity |
| Network IDS | Suricata | Port scans, SYN floods, known exploits |
| Correlation | Wazuh Rules | Brute-force thresholds, attack sequences |
| Auto-response | Wazuh Active Response | Auto-block attacking IPs via iptables |
| Visualization | Kibana | Attack dashboards, alert timelines |

---

## Requirements

| Component | Minimum | Recommended |
|---|---|---|
| RAM | 4 GB | 8 GB |
| Disk | 20 GB | 40 GB |
| CPU | 2 cores | 4 cores |
| OS | Linux / macOS | Ubuntu 22.04 |
| Docker | 20.x+ | Latest |

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/ihorbezruchko/soc-attack-detection-lab.git
cd soc-attack-detection-lab

# 2. Run setup (installs tools, generates TLS certs, starts stack)
chmod +x setup.sh
sudo ./setup.sh

# 3. Wait ~3 minutes for services to initialize

# 4. Open Kibana
open http://localhost:5601
# Username: elastic
# Password: SecretPassword1!
```

---

## Running Attack Simulations

### SSH Brute Force

```bash
# From your host
chmod +x attacks/ssh_bruteforce.sh
./attacks/ssh_bruteforce.sh 172.20.0.13 22

# Or from inside the attacker container
docker exec -it attacker bash
bash /attacks/ssh_bruteforce.sh 172.20.0.13 22
```

**What happens:**
1. Nmap scans SSH version
2. Hydra fires 380 login attempts (20 users × 19 passwords)
3. Wazuh detects burst of `Failed password` events
4. Rule 5712 fires at attempt #8 — **SIEM alert generated**
5. Active response blocks the attacker IP for 10 minutes
6. Kibana shows alert with attacker IP, targeted users, timestamps

### Port Scanning

```bash
chmod +x attacks/port_scan.sh
./attacks/port_scan.sh 172.20.0.13
```

**What happens:**
1. SYN scan → Suricata SID 9000010
2. NULL scan → Suricata SID 9000011
3. FIN scan  → Suricata SID 9000012
4. XMAS scan → Suricata SID 9000013
5. UDP scan  → Suricata SID 9000014
6. OS detect → Suricata SID 9000015
7. All events forwarded to Kibana via Wazuh agent

---

## Kibana Queries

After running attacks, search in Kibana's Discover view:

**All brute-force alerts:**
```
rule.id: 5712 OR rule.id: 5716
```

**All Suricata port scan alerts:**
```
event.module: suricata AND alert.signature_id: [9000010 TO 9000015]
```

**Alerts from attacker IP:**
```
data.srcip: 172.20.0.99
```

**Critical alerts only:**
```
rule.level: >= 12
```

**All alerts in last hour:**
```
@timestamp: [now-1h TO now]
```

---

## How Detection Works

### Brute-Force Detection (Wazuh)

Wazuh uses a **frequency correlation engine**:

```
Event: "Failed password for root from 185.x.x.x"
         ↓
Rule 5710 fires (level 5) — single failure
         ↓
Same IP fires rule 5710 again within 120 seconds
         ↓
Counter increments: 2, 3, 4, 5, 6, 7, 8...
         ↓
At count ≥ 8 → Rule 5712 fires (level 10)
"sshd: SSHD brute force trying to get access to the system"
         ↓
Active Response: iptables -I INPUT -s <IP> -j DROP
```

### Port Scan Detection (Suricata)

Suricata uses **threshold rules** on network packets:

```
Packet: TCP SYN → port 445 (from 172.20.0.99)
Packet: TCP SYN → port 22  (from 172.20.0.99)
Packet: TCP SYN → port 80  (from 172.20.0.99)
... 20 packets in 10 seconds ...
         ↓
Threshold exceeded → Rule SID 9000010 fires
"SOC-LAB Nmap SYN Port Scan Detected"
         ↓
EVE JSON written to /var/log/suricata/eve.json
         ↓
Wazuh agent reads file → forwards to Wazuh Manager
         ↓
Wazuh indexes to Elasticsearch → visible in Kibana
```

---

## Project Structure

```
soc-attack-detection-lab/
│
├── docker-compose.yml          # Full SOC stack definition
├── setup.sh                    # Automated setup script
│
├── wazuh/
│   └── config/
│       └── ossec.conf          # Wazuh detection rules & config
│
├── suricata/
│   └── rules/
│       └── local.rules         # Custom Suricata IDS rules
│
├── attacks/
│   ├── ssh_bruteforce.sh       # SSH brute force simulation
│   └── port_scan.sh            # Multi-technique port scan simulation
│
├── docs/
│   ├── architecture.md         # Detailed architecture explanation
│   └── attack_scenarios.md     # Attack analysis & MITRE mapping
│
├── screenshots/                # Add your alert screenshots here
└── README.md
```

---

## MITRE ATT&CK Coverage

| Technique | ID | Attack Script | Detection |
|---|---|---|---|
| Brute Force: Password Spraying | T1110.003 | ssh_bruteforce.sh | Wazuh 5712 |
| Valid Accounts | T1078 | ssh_bruteforce.sh | Wazuh 5715 |
| Network Service Discovery | T1046 | port_scan.sh | Suricata 9000010+ |
| OS Fingerprinting | T1592 | port_scan.sh | Suricata 9000015 |
| Sudo Abuse | T1548.003 | Manual | Wazuh 5401 |

---

## Useful Commands

```bash
# View live Wazuh alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json | python3 -m json.tool

# View live Suricata alerts
docker exec suricata tail -f /var/log/suricata/fast.log

# Check all container status
docker-compose ps

# Restart a single service
docker-compose restart wazuh-manager

# Stop the entire lab
docker-compose down

# Full reset (removes all data)
docker-compose down -v
```

---

## Stopping the Lab

```bash
# Stop containers (preserves data)
docker-compose stop

# Remove containers and networks
docker-compose down

# Full cleanup including volumes
docker-compose down -v --remove-orphans
```

---

## Tech Stack

| Component | Version | Role |
|---|---|---|
| Wazuh | 4.7.0 | SIEM / HIDS |
| Suricata | Latest | Network IDS |
| Elasticsearch | 7.17.13 | Log storage |
| Kibana | 7.17.13 | Visualization |
| Docker Compose | 3.8 | Orchestration |
| Kali Linux | Rolling | Attack simulation |

---

## Author

**Ihor Bezruchko**
IT Support Specialist | Junior SOC Analyst
Luxembourg

[GitHub](https://github.com/ihorbezruchko) · [LinkedIn](https://linkedin.com/in/ihorbezruchko)

---

> ⚠️ **Disclaimer:** This lab is for educational purposes only. All attack simulations are performed in an isolated Docker network. Never run these scripts against systems you do not own.
