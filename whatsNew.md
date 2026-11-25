# AS2Go | What's New

AS2Go began as a Windows batch demonstration for Microsoft Defender for Identity in 2021. It grew into a standalone PowerShell script and, in 2026, became a PowerShell 7 module for Active Directory security demonstrations and detection validation in controlled labs.

## Version history

| Date | Milestone | Functions | Lines | Files |
| --- | --- | ---: | ---: | ---: |
| May 2021 | Microsoft Defender for Identity demo (`mdi-demo.cmd`) | — | — | 1 |
| Aug 2021 | AS2Go v1.0 | 32 | 2,139 | 1 |
| Dec 2021 | AS2Go v2.5 | 46 | 3,483 | 1 |
| Apr 2023 | AS2Go v2.8 | 62 | 5,077 | 1 |
| Oct 2023 | AS2Go v3.x | 75 | 6,490 | 1 |
| Feb 2026 | AS2Go PowerShell module | 128 | 11,589 | 74 |
| Nov 2026 | AS2Go PowerShell module | 206 | 17,488 | 171 |

The August 2021 through November 2026 figures come from the project timeline and represent snapshots.

## Release highlights

### November 2026 · AS2Go PowerShell module

2026.11.16.1272
- Protects sensitive configuration values, including saved password hashes, with Windows DPAPI. Protected values can be decrypted only on the Windows computer that saved them and are omitted from logs.
- Provides illustrated scenario guides with security lessons and references, so workshop participants can review each scenario before or after the demo.
- Provisions fresh ESC1 and ESC4 certificate templates for authorized labs without requiring a separate AD CS module. Verify Config shows the ESC1 template used by the scenario.
- Makes Domain Persistence actions easier to find with clearer menu labels and distinct keyboard shortcuts, including a shortcut to skip the phase.


2026.11.13.1258
- Follow the updated setup guide to configure AS2Go, verify your lab settings, and troubleshoot common setup issues.
- Run AS2Go with PowerShell 7.4 or later.
- Use `-SafeMode` to skip selected actions while walking participants through a guided lab demo.
- Save direct memberships in privileged groups to a timestamped JSON file and restore those memberships alongside current members. Domain Persistence can refresh the backup before the group membership removal exercise.
- Check domain controller access, required tools, DNS zone transfers, and Active Directory Certificate Services before starting a demo.
- Use the updated Privilege Escalation walkthrough to explore Pass-the-Ticket and Overpass-the-Hash and discuss the activity defenders can look for in the lab.
- Use the Golden Ticket demonstration to explore how forged Kerberos tickets affect domain security.
- New function to create a set of Active Directory demo principals in one step to spend less time preparing the lab.

### February 2026 · Transition to a PowerShell 7 module

The new module organized the scenarios into reusable phases and introduced structured Active Directory lab preparation. The module supports multi-domain forests and lets users scope a simulation to an OU, a domain, or the forest. [AS2Go 2026 announcement](https://herrhozi.com/2026/05/21/as2go/)

### AS2Go 3.0

- Added a Group Policy Template demonstration covering built-in group membership, scheduled tasks, and user rights assignments. [Original What's New post](https://herrhozi.com/2023/10/08/whats-new/)

### AS2Go 2.9

- Improved certificate template checks. See the [AD CS ESC1 article](https://herrhozi.com/2023/09/09/as2go-how-one-certificate-template-misconfiguration-esc1-can-lead-to-complete-active-directory-ad-forest-compromise/).
- Updated syntax highlighting and made output from supporting functions easier to see.
- Updated the lab setup scripts for [demo accounts](https://youtu.be/2YRYa99hXpY) and the [organizational unit structure](https://herrhozi.com/as2go-lab-setup-1-3-dc/).

### AS2Go 2.5

- Fixed minor bugs and added `-DeveloperMode` to speed up testing.

### AS2Go 2.0

- Added a [ransomware simulation](https://herrhozi.com/as2go-prepare-run-the-attack-ransomware/).

### May 2021 · Initial Microsoft Defender for Identity demo

The initial milestone was a Windows batch file named `mdi-demo.cmd`, used to demonstrate an Active Directory security scenario with Microsoft Defender for Identity. The surviving copy identifies itself as version **1.31**, dated **July 26, 2021**, and contains **776 physical lines** and **13 batch labels**. The July revision contains no subroutines invoked with `CALL :Label`.

| Area | Batch labels |
| --- | --- |
| Entry point | `STEP0` |
| Lateral movement and credentials | `LATERALMOVEMENT`, `PtH`, `HDHASH`, `PtT` |
| Data exfiltration | `TryToExfiltrate` |
| Domain compromise and persistence | `DOMAINCOMPROMISED`, `GoldenTicket` |
| Shared resources, user accounts, and systems | `SharedResources`, `DISABLEUSERS`, `Reboot`, `SHUTDOWN` |
| Cleanup and script exit | `CleanUP`, `END` |
