# ASP00 | Start the AS2Go Demo

`Start-AS2GoDemo` starts the interactive AS2Go workflow under the currently signed-in account. Choose a starting point in the attack chain; the workflow runs that phase and the subsequent phases through Phase 12, Domain Persistence.

## Before you start

- Complete the required lab preparation in [ASP00 Installation and Setup](ASP00-Setup.md), including applicable items in its [ASP00 documentation map](ASP00-Setup.md#asp00-documentation-map).
- Sign in to the member server in the separate Windows session for the compromised non-Tier 0 account. This account must also be a local administrator on the member server.
- Open PowerShell 7.4 in elevated mode. AS2Go records the current logon account as the compromised account for the workflow.
- Ensure the lab configuration and tools are ready for the phases you plan to run. The workflow checks for the ActiveDirectory and GroupPolicy modules and configured AS2Go tools. Missing dependencies produce a warning; phases that require them may not work.

Use AS2Go only in an explicitly authorized lab. Review the [shared setup and safety guidance](ASP00-Setup.md#scope-and-safety) and the documentation for the phases you intend to run.

## Start the workflow

Run the command from the elevated PowerShell 7.4 session:

```powershell
Start-AS2GoDemo
```

Review the disclaimer and continue only in the prepared, authorized lab. The workflow then asks where to start. Each choice runs the selected phase and the phases that follow it:

| Starting point | Phases run |
|---|---|
| Password Spray (ASP04) | ASP04, ASP05, ASP06, ASP07, ASP09, ASP10, ASP11, ASP12 |
| Initial Access (ASP05) | ASP05, ASP06, ASP07, ASP09, ASP10, ASP11, ASP12 |
| Reconnaissance (ASP06) | ASP06, ASP07, ASP09, ASP10, ASP11, ASP12 |
| Privilege Escalation (ASP07) | ASP07, ASP09, ASP10, ASP11, ASP12 |
| Privileged Reconnaissance (ASP09) | ASP09, ASP10, ASP11, ASP12 |
| Sensitive Data Access (ASP10) | ASP10, ASP11, ASP12 |
| Data Exfiltration (ASP11) | ASP11, ASP12 |
| Domain Persistence (ASP12) | ASP12 |

Review the guide for each selected phase before running the workflow. Individual phases can modify the lab environment or create artifacts. Snapshot the lab and coordinate monitoring before execution.

## Preview the workflow

To browse the workflow offline without running attack actions, use:

```powershell
Start-AS2GoDemo -Preview
```

Preview opens a separate menu. Runtime phase selection and skip options do not apply in preview mode.

For additional supported options, see the [`Start-AS2GoDemo` switch reference](ASP00-Setup.md#start-as2godemo) in the parent setup guide.

## Related documentation

- [ASP00 Installation and Setup](ASP00-Setup.md)
- [ASP04 Password Spray](ASP04_Password-Spray.md)
- [ASP05 Initial Access](ASP05_Initial-Access.md)
- [ASP06 Reconnaissance](ASP06_Reconnaissance.md)
- [ASP07 Privilege Escalation](ASP07-PrivilegeEscalation.md)
- [ASP09 Privileged Reconnaissance](ASP09_Reconnaissance-Privileged.md)
- [ASP10 Sensitive Data Access](ASP10_Sensitive-Data-Access.md)
- [ASP11 Data Exfiltration](ASP11_Data-Exfiltration.md)
- [ASP12 Domain Persistence](ASP12-DomainCompromisePersistence.md)