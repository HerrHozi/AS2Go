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

- Added native support for provisioning ESC1 and ESC4 certificate templates in the lab and for checking the configured scenario templates during verification.
- Updated the setup guide for PowerShell 7.4 and expanded configuration verification and troubleshooting guidance.
- Added optional machine-scoped DPAPI protection for configuration values.

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
