# Incident Report — Domain Controller Compromise and Data Exfiltration

**Environment:** C137.local (lab)
**Affected systems:** CITADEL-DC01 (domain controller), DESKTOP-SDN1RPT (workstation)
**Analyst:** Fatema Johra
**Classification:** Confirmed intrusion — full domain compromise with data exfiltration

> This is a training exercise built on the public DFIR Madness "Stolen Szechuan Sauce" dataset. The organization "C137.local" and all user names are fictional; no real organization or data is involved. The report is written as it would be for a real incident, from the evidence only.

---

## 1. Executive summary

An external attacker compromised the C137.local domain by brute-forcing the built-in Administrator account over Remote Desktop (RDP), which was reachable directly from the internet. Within minutes the attacker downloaded and ran malware on the domain controller, escalated to SYSTEM, established an encrypted command-and-control (C2) channel, and installed persistence. Using the stolen Administrator credentials, the attacker moved laterally to a workstation and repeated the same steps there. Sensitive files were opened, one was altered, and an archive of personal files was exfiltrated to the C2 server.

The intrusion is a **full domain compromise**. The attacker held SYSTEM-level access on the domain controller, which stores the credentials for every account in the domain, and the C2 connection was still active when the evidence was collected.

The root cause is a combination of three failures: RDP exposed to the internet, a weak and reused Administrator password, and no account-lockout policy to stop the brute force.

---

## 2. Scope and evidence

**Systems in scope**

| Host | Role | IP |
|---|---|---|
| CITADEL-DC01 | Domain controller, DNS, file share | 10.42.85.10 |
| DESKTOP-SDN1RPT | Windows 10 workstation | 10.42.85.115 |

Domain: C137.local. Internal network: 10.42.85.0/24, gateway 10.42.85.100. The gateway was configured to allow inbound RDP from the internet to the domain controller.

**Evidence examined**

- Disk images of both hosts
- Memory images of both hosts
- Full network packet capture
- Windows event logs, registry hives, and `NTDS.dit` from the domain controller

**Evidence integrity.** Every working file was hashed (SHA-256) before analysis and verified again at the end; all values matched, and the originals were held read-only on separate media. Key artifact:

- `coreupdater.exe` (malware) — SHA-256 `10f3b92002bb98467334161cf85d0b1730851f9256f83c27db125e9a0c1cfda6`

**A note on time.** The domain controller and the workstation clocks both ran one hour ahead of true time, confirmed by comparing host logs against the packet capture. All times in this report are **network (true) time**; host-log times are one hour later.

---

## 3. Timeline of the attack

All times UTC (network/true time).

| Time | Event |
|---|---|
| 02:19:13 | Nmap scan of the domain controller from 194.61.24.102 |
| 02:21:26–47 | RDP brute force of the Administrator account (95 failed attempts) |
| 02:21:48 | Successful RDP logon from 194.61.24.102 |
| 02:24:06 | Domain controller downloads `coreupdater.exe` over HTTP from 194.61.24.102 |
| 02:24:12 | `coreupdater.exe` placed in `C:\Windows\System32` |
| 02:25:18 | First C2 callback to 203.78.103.109:443 |
| 02:25:44 | First privilege-escalation service (`getsystem`) |
| 02:27:49 | `coreupdater` persistence service installed on the domain controller |
| 02:32:02–21 | Attacker opens secret files (portal gun plans, Beth note, Szechuan Sauce) |
| 02:34:27 | `SECRET_beth.txt` edited, then deleted |
| ~02:35 | `Beth_Secret.txt` planted with falsified (time-stomped) timestamps |
| 02:36:24 | Lateral movement: RDP from the domain controller to the workstation using the stolen Administrator credentials |
| 02:39:58 | Workstation downloads `coreupdater.exe` |
| 02:40:49 | Workstation runs the malware; first workstation C2 callback |
| 02:42:42 | `coreupdater` persistence service installed on the workstation |
| 02:46:18 | `loot.zip` (131,041 bytes) assembled in the workstation user's Documents |
| 02:47:06 | ~128 KB exfiltrated to the C2 server |
| 02:52:13 | Lateral RDP session disconnected |
| 02:56:04 | Second attacker RDP logon to the domain controller |
| 02:57:41 | Attacker logs off the domain controller |
| 05:38:51 | C2 still beaconing (60-second heartbeat) when the capture ends |

---

## 4. Findings

**4.1 Initial access.** The attacker reached the domain controller's RDP service, exposed to the internet through the gateway, and ran an automated brute force against the Administrator account: 95 failed logons in about one minute, followed by a successful logon from 194.61.24.102. There was no account-lockout policy to stop it.

**4.2 Malware.** The attacker downloaded `coreupdater.exe` (7,168 bytes) over HTTP and placed it in `System32`. VirusTotal identifies it as a Metasploit-generated loader (64 of 71 vendors); it fetches a larger Meterpreter payload (~380 KB) and runs it in memory. The same file, with the same hash, was later run on the workstation.

**4.3 Privilege escalation.** The attacker escalated to SYSTEM using Meterpreter's `getsystem`, confirmed by several short-lived named-pipe services on both hosts (event 7045).

**4.4 Command and control.** Both hosts maintained encrypted C2 sessions to 203.78.103.109:443. The loader called home within a minute of running on each host. VirusTotal independently links this address to `coreupdater.exe`.

**4.5 Persistence.** On both hosts the malware registered itself as an auto-start Windows service named `coreupdater`, running as LocalSystem, pointing at the file in `System32`.

**4.6 Defense evasion.** In memory, the malware migrated into `spoolsv.exe` (Print Spooler) and exited, leaving the C2 connection running inside a trusted process. Injected Metasploit shellcode was recovered from `spoolsv.exe` on both hosts.

**4.7 Lateral movement.** The attacker used the stolen Administrator credentials to RDP from the domain controller to the workstation (confirmed from both hosts' logs), then repeated the download, execution, escalation, and persistence steps.

**4.8 Data accessed and altered.** On the domain controller the attacker opened files in `C:\FileShare\Secret`, including a sensitive text file. One file (`SECRET_beth.txt`) was edited and deleted, and a replacement (`Beth_Secret.txt`) was planted with falsified timestamps copied from another file to disguise it as original — i.e. evidence tampering.

**4.9 Data exfiltration.** On the workstation the attacker collected three files from a user's Documents into `loot.zip` (131,041 bytes) and sent ~128 KB to the C2 server 48 seconds later. The archive was then deleted, but its contents were reconstructed from file-system metadata: an image file, a plans text file, and a file containing a Social Security number.

**4.10 Credential exposure.** Because the attacker held SYSTEM on the domain controller, the entire domain credential store was exposed. The Administrator password was recovered from the domain database and was found in public breach wordlists — it met complexity requirements but was already a known, reused password.

**4.11 Attacker still active at collection.** The C2 connections never closed. Three sessions (one on the domain controller, two on the workstation) were still sending a 60-second heartbeat when the capture ended, so the attacker retained access at the time of evidence collection.

---

## 5. Indicators of compromise

| Type | Value |
|---|---|
| Entry / malware-host IP | 194.61.24.102 (Moscow, RU; anonymizing service) |
| C2 IP | 203.78.103.109:443 (Bangkok, TH; hosting) |
| Malware file | `C:\Windows\System32\coreupdater.exe`, 7,168 bytes |
| SHA-256 | `10f3b92002bb98467334161cf85d0b1730851f9256f83c27db125e9a0c1cfda6` |
| MD5 | `eed41b4500e473f97c50c7385ef5e374` |
| Persistence | service `coreupdater` @ `HKLM\SYSTEM\CurrentControlSet\Services\coreupdater` |
| Escalation services | `outmgo`, `mszhao`, `pmhrio` (DC); `nehgye` (workstation) |
| Injected process | `spoolsv.exe` (both hosts) |
| Exfiltrated | `loot.zip` (131,041 bytes) to 203.78.103.109 |
| Tampered file | `Beth_Secret.txt` (time-stomped, replaced `SECRET_beth.txt`) |

---

## 6. Impact

- **Full domain compromise.** SYSTEM-level access on the domain controller exposes every credential in C137.local. All domain accounts must be treated as compromised.
- **Active intruder.** C2 was live at evidence-collection time; the attacker could still act in the environment.
- **Data loss.** Personal files, including a file containing a Social Security number, were exfiltrated.
- **Integrity loss.** At least one file was altered and disguised, so data on the affected systems cannot be trusted without verification.
- **Two hosts confirmed compromised,** with persistence on both.

---

## 7. Containment and recommendations

**Immediate containment**

1. Restrict outbound traffic from the domain controller to only required, approved destinations while investigating; do not return it to unrestricted internet access. Block 194.61.24.102 and 203.78.103.109 at the firewall.
2. Block public inbound RDP to the domain controller and disable any internet-facing port forwarding or equivalent access rules. Allow RDP only through an approved VPN, gateway, or managed administrative path.
3. Remove the `coreupdater` service and file from both hosts (or rebuild the hosts), and reset the Administrator password and all domain credentials, since the attacker held SYSTEM on the domain controller.
4. Have Active Directory specialists determine whether the environment can be safely remediated in place or requires a broader recovery plan.

**Recommendations**

1. Allow remote access only through a VPN with MFA, an RD Gateway, or a managed bastion, and restrict inbound traffic at the firewall or security group.
2. Require MFA for remote access and use unique, strong credentials; screen passwords against known-breached lists, because the recovered Administrator password met complexity rules yet was already public. Set an account-lockout policy per Microsoft's baseline (lock for 15 minutes after 10 failed attempts, reset the counter after 15 minutes); in this incident 95 failed attempts in one minute triggered no lockout.
3. Apply least privilege and separate administrative accounts by role and system tier. Do not use the domain Administrator account for everyday logons.
4. Restrict and monitor outbound network access from domain controllers.
5. Monitor and alert on repeated failed logons and unexpected successful RDP logons, and review the logs regularly.
6. Improve visibility: enable process-creation logging (event 4688 with command lines), synchronize all clocks to one reliable time source, and forward logs to a central SIEM the attacker cannot reach.

**Mapping to CIS Controls v7.1**

- **Control 4 — Controlled Use of Administrative Privileges.** A single cracked, reused Administrator credential opened both hosts. (Supports: NIST SP 800-53 AC-6.)
- **Control 9 — Limitation of Ports, Protocols, and Services.** RDP was exposed to the internet and discovered by scanning; internal port scanning would have found it first.
- **Control 12 — Boundary Defense.** The attack crossed the boundary inbound (brute force) and outbound (HTTP download, sustained C2). Firewall, IDS, and IPS controls would each have had a detection opportunity.
- **Control 16 — Account Monitoring and Control.** 95 failed logons with no lockout and a foreign-IP Administrator logon with no alert. (Supports: NIST SP 800-63-4.)

**Architecture priority.** The single highest-value improvement is central logging and monitoring (a SIEM). The access controls above close the exposed RDP path; the remaining gap is visibility. None of the brute force, the foreign-IP logon, the new services, or the hours of beaconing were detected at the time.

**Supporting policies.** Password policy (long, unique, no reuse, screened against breach lists), remote-access policy (RDP only via VPN or gateway with MFA), account-lockout policy, and a logging and audit policy defining what is collected (events 4625, 4688, 7045), retention, and clock synchronization.

---

## 8. Open questions

- **Who launched the malware.** The process that started `coreupdater.exe` had exited before memory was captured, so its parent could not be identified from memory. Timing indicates manual execution by the attacker but this is not proven.
- **Whether a specific sensitive recipe file was exfiltrated.** The file was opened on screen over RDP. The domain controller sent no bulk upload, and the C2 traffic is encrypted, so transfer of this specific 478-byte file can be neither confirmed nor ruled out.
