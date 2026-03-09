# Attack Scenarios & Detection Analysis

## Scenario 1: SSH Brute Force

### Attack Description
An attacker systematically tries username/password combinations against the SSH service, attempting to gain unauthorized access.

### Tools Used
- **Hydra** — parallel login cracker
- **Medusa** — alternative brute-forcer
- **Manual SSH** — simulates human attacker

### Attack Phases
```
1. Reconnaissance    → nmap -sV -p 22 (detect SSH version)
2. User enumeration  → try invalid usernames, measure response time
3. Brute force       → hydra -L users.txt -P passwords.txt ssh://target
4. Credential use    → ssh root@target (if credentials found)
```

### Detection Method

**Wazuh (Host-based):**
```
Rule 5710  — sshd: Attempt to login using a denied user
Rule 5711  — sshd: Attempt to login using a non-existent user
Rule 5712  — sshd: SSHD brute force trying to get access to the system (>8 attempts)
Rule 5716  — sshd: Multiple authentication failures
```

Wazuh uses a **frequency counter** — if rule 5710/5711 fires 8+ times from the same IP within 120 seconds, it escalates to rule 5712 (level 10 alert).

**Suricata (Network-based):**
```
SID 9000001 — SSH Brute Force (5 SYN packets to port 22 in 60s)
SID 9000002 — SSH Rapid Connection Cycling (10 connections in 30s)
```

### Active Response
When rule 5712 fires, Wazuh automatically runs `firewall-drop`:
```bash
# Wazuh executes this on the target:
iptables -I INPUT -s <ATTACKER_IP> -j DROP
```
The IP is blocked for 600 seconds (10 minutes).

### Kibana Query
```
rule.id: 5712 OR rule.id: 5716
```

---

## Scenario 2: Port Scanning

### Attack Description
Attacker maps the network to discover open ports, running services, and OS fingerprint before launching targeted attacks.

### Tools Used
- **nmap** — industry standard port scanner
- **masscan** — high-speed scanner
- **hping3** — packet crafting

### Scan Types & Detection

| Scan Type | nmap flag | TCP Flags | Suricata SID | How it works |
|---|---|---|---|---|
| SYN Scan | `-sS` | SYN | 9000010 | Sends SYN, waits for SYN-ACK, never completes |
| NULL Scan | `-sN` | None | 9000011 | No flags — RFC says closed ports reply RST |
| FIN Scan | `-sF` | FIN | 9000012 | FIN without established connection |
| XMAS Scan | `-sX` | FIN+PSH+URG | 9000013 | All flags set (like a Christmas tree) |
| UDP Scan | `-sU` | — | 9000014 | UDP probes; ICMP unreachable = closed |
| OS Detect | `-O` | SF | 9000015 | Probes with specific TTL/window values |

### Why These Are Suspicious
- Normal TCP traffic follows the 3-way handshake (SYN → SYN-ACK → ACK)
- NULL/FIN/XMAS packets are never sent in legitimate traffic
- A single host scanning 20+ ports in 10 seconds is statistically impossible for legitimate use

### Suricata Detection Logic
```
# Threshold rule — count-based
alert tcp any any -> $HOME_NET any (
    threshold: type threshold, track by_src, count 20, seconds 10;
    ...
)
```

Suricata counts packets **per source IP**. If 20+ SYN packets arrive from one IP in 10 seconds → alert.

---

## Scenario 3: Privilege Escalation

### Attack Description
After gaining initial access (e.g., via weak SSH credentials), the attacker tries to escalate to root.

### Techniques
```bash
# sudo brute force
for pass in password admin 123456; do
    echo "$pass" | sudo -S id 2>/dev/null && break
done

# Check for SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Check sudo rules
sudo -l
```

### Detection
**Wazuh rules:**
```
Rule 5401  — Possible attack on the sudo program
Rule 5402  — sudo: Successful sudo to ROOT
Rule 2502  — User missed the password more than one time
```

**Custom rule in ossec.conf:**
```xml
<rule id="100001" level="12">
  <if_matched_sid>5401</if_matched_sid>
  <same_source_ip />
  <description>Repeated sudo failures — privilege escalation attempt</description>
  <mitre>
    <id>T1548.003</id>
  </mitre>
</rule>
```

### MITRE ATT&CK Mapping

| Technique | ID | Description |
|---|---|---|
| Brute Force | T1110 | Attempting to access or escalate privileges |
| Valid Accounts | T1078 | Using obtained credentials |
| Sudo Abuse | T1548.003 | Sudo and Sudo Caching |
| Network Scanning | T1046 | Network Service Discovery |

---

## Alert Severity Guide

| Wazuh Level | Meaning | Response |
|---|---|---|
| 0-3 | Informational | Log only |
| 4-7 | Low | Monitor |
| 8-11 | Medium | Investigate |
| 12-14 | High | Respond |
| 15 | Critical | Immediate action |

Brute-force (rule 5712) = **Level 10 (High)**
Successful login from attacker = **Level 12+ (Critical)**
