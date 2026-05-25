SOC Attack Detection Lab
A fully containerised Security Operations Center lab built with open-source tools.
Designed to simulate real attack scenarios and practice detection engineering.
Show Image Show Image Show Image Show Image

Architecture
Attack Simulation
      │
      ▼
┌─────────────┐     ┌──────────────┐
│  Wazuh SIEM │     │   Suricata   │
│  (log corr) │     │  IDS (net)   │
└──────┬──────┘     └──────┬───────┘
       │                   │
       └─────────┬─────────┘
                 ▼
     ┌───────────────────────┐
     │  Elasticsearch        │
     │  + Kibana Dashboard   │
     └───────────────────────┘

Stack
ToolVersionPurposeWazuh4.7SIEM — log collection, correlation, alertingSuricata7.0IDS — network threat detectionElasticsearch8.12Log storage and searchKibana8.12Dashboards and visualisationDocker Compose—Orchestration

Quick Start
bashgit clone https://github.com/ihorpjp/soc-attack-detection-lab
cd soc-attack-detection-lab
docker compose up -d
Access after startup:

Kibana: http://localhost:5601
Wazuh Dashboard: https://localhost:443

Wait ~2 minutes for all services to initialise.

What it detects
AttackTechniqueDetection sourceSSH Brute ForceT1110.001Wazuh rule 5760Port ScanningT1046Suricata ET SCAN rulesFailed sudo attemptsT1548.003Wazuh rule 5402New user createdT1136.001Wazuh rule 5902Reverse shell attemptT1059Suricata custom rule

MITRE ATT&CK Coverage
TacticTechnique IDTechnique NameCredential AccessT1110Brute ForceDiscoveryT1046Network Service DiscoveryPrivilege EscalationT1548Abuse Elevation Control MechanismPersistenceT1136Create AccountExecutionT1059Command and Scripting Interpreter

Attack simulation examples
bash# Simulate SSH brute force (from attacker machine)
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://TARGET_IP

# Port scan
nmap -sS -p 1-1000 TARGET_IP

# Failed sudo attempts
for i in {1..10}; do sudo -u wronguser whoami 2>/dev/null; done

Requirements

Docker + Docker Compose
4GB RAM minimum (8GB recommended)
Linux or macOS host


Related projects

soc-pipeline — full IR pipeline built on top of this lab
soc-log-analyzer — Python brute-force detection toolwww.linkedin.com/in/ihor-bezruchko-31637a2b7/)

---

> ⚠️ **Disclaimer:** This lab is for educational purposes only. All attack simulations are performed in an isolated Docker network. Never run these scripts against systems you do not own.
