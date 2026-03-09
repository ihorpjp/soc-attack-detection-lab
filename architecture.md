# SOC Architecture — Attack Detection Lab

## Overview

This lab replicates a real SOC (Security Operations Center) environment in miniature. The architecture follows the **collect → detect → alert → visualize** pipeline used by enterprise security teams.

---

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Network: 172.20.0.0/24                │
│                                                                  │
│  ┌─────────────────┐          ┌──────────────────────────────┐  │
│  │  ATTACKER        │          │  MONITORING STACK            │  │
│  │  172.20.0.99     │          │                              │  │
│  │                  │  attack  │  Wazuh Manager  172.20.0.12  │  │
│  │  Kali Linux      │─────────▶│  Wazuh Agent    172.20.0.13  │  │
│  │  - nmap          │          │  Suricata IDS   (host net)   │  │
│  │  - hydra         │          │  Elasticsearch  172.20.0.10  │  │
│  │  - hping3        │          │  Kibana         172.20.0.11  │  │
│  │  - masscan       │          │                              │  │
│  └─────────────────┘          └──────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Roles

### Wazuh Manager
- Central SIEM brain
- Receives logs from agents via encrypted channel (port 1514)
- Runs correlation rules against log data
- Triggers active response (auto-blocking)
- Forwards enriched alerts to Elasticsearch

### Wazuh Agent
- Installed on the "target" machine (the one being attacked)
- Monitors: `/var/log/auth.log`, `/var/log/syslog`, Suricata logs
- Sends events to Wazuh Manager in near-real-time

### Suricata IDS
- Network-based intrusion detection (layer 3/4)
- Inspects all network packets in real time
- Uses signature rules to detect scan types and attack patterns
- Outputs alerts to EVE JSON format (`/var/log/suricata/eve.json`)
- Wazuh agent reads EVE JSON and forwards to SIEM

### Elasticsearch
- Time-series log storage and search engine
- Stores all Wazuh alerts and Suricata events
- Indexed by `wazuh-alerts-*` and `filebeat-*` patterns

### Kibana
- Web UI for querying and visualizing data
- Dashboards show attack timelines, IP maps, alert counts
- Wazuh plugin provides pre-built SOC dashboards

---

## Data Flow

```
Auth.log / Syslog
      │
      ▼
 Wazuh Agent ──── collects ──── Suricata EVE JSON
      │
      │ (TLS encrypted, port 1514)
      ▼
 Wazuh Manager
      │
      ├── Rule correlation engine
      │       └── Matches against 3000+ built-in rules
      │
      ├── Active Response
      │       └── firewall-drop on brute-force IPs
      │
      ▼
 Filebeat (inside Wazuh)
      │
      │ (HTTP, port 9200)
      ▼
 Elasticsearch
      │
      ▼
 Kibana Dashboard
```

---

## Detection Layers

| Layer | Tool | What it detects |
|---|---|---|
| Host-based (HIDS) | Wazuh | Failed logins, sudo abuse, file changes |
| Network-based (NIDS) | Suricata | Port scans, flood attacks, known exploits |
| Correlation | Wazuh Rules | Brute-force thresholds, sequences |
| Response | Wazuh Active Response | Auto-block attacking IPs via iptables |

---

## Ports Reference

| Port | Service | Protocol |
|---|---|---|
| 5601 | Kibana Dashboard | HTTP |
| 9200 | Elasticsearch API | HTTP |
| 55000 | Wazuh API | HTTPS |
| 1514 | Wazuh Agent communication | TCP |
| 1515 | Wazuh Agent enrollment | TCP |
| 514 | Syslog (Suricata) | UDP |
| 22 | SSH (target machine) | TCP |
