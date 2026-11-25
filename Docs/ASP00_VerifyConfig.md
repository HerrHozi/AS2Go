# ASP00 Verify Config

Use **Verify Config** in the public `Initialize-AS2GoLab` setup menu to review the current AS2Go lab configuration. The menu calls the internal `Invoke-VerifyConfiguration` function; users start the review through the public setup menu.

The review runs a series of checks and inventories, continues after individual query failures, and finishes with a summary. The summary shows which check categories are **Existing**, **Missing**, or **Could not be verified**. Details printed before the summary identify specific missing files, settings, or objects where available.

## Workflow overview

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **Verify Config**.
    - `Invoke-VerifyConfiguration` *(internal review)*
      - Check local tools, saved accounts, workstation connectivity, and the backup share.
      - Inventory directory assets, enterprise CAs, the ESC1 template, Web Enrollment, DNS zone transfers, and the MDI honeytoken.
      - Print **Verification Summary** with a result for every check category.

## Menu option

```powershell
Initialize-AS2GoLab
```

Complete the setup prompts and select **Verify Config**. The check uses the current saved settings and discovered lab environment. It does not prompt to create or repair missing items.

## Checks performed

| Check | What it reviews |
|---|---|
| Lab tools | Configured tools folder and presence of `NetSess.exe`, `Mimikatz.exe`, `Rubeus.exe`, `Certify.exe`, and `PsExec.exe`. |
| Break-glass account | Whether a break-glass account is configured. |
| Secure Access Workstation | Whether an SAW/Admin PC is configured and WinRM is reachable on TCP 5985. |
| Directory assets | Tiering OUs and groups, plus demo accounts, in the current domain. |
| Enterprise CAs and ESC1 certificate template | Enterprise CAs and the exact `<Scenario> ESC1` template name, using the setup scenario prefix. |
| AD CS Web Enrollment feature | Enrollment services and the Web Enrollment feature on the forest-root domain controller. |
| AD backup share | Whether the configured share path is reachable and contains `ntds.dit` and `daily-work.txt`. |
| DNS zone transfers | Whether primary zones for the forest root domain allow transfers to any server on the setup DNS server. |
| MDI honeytoken | Whether a honeytoken account is configured. |

The review is read-only: it queries the lab and checks local paths, but does not create accounts, modify DNS or AD CS, or repair missing configuration. Query failures are reported separately and do not stop the remaining checks.

## Read the final summary

At the end of the run, look for **Verification Summary**. Each row represents one check category:

- **Existing** — the check completed without reporting a missing item.
- **Missing** — the check reported one or more missing settings, files, or objects. Review the detailed output above the summary to see what is missing.
- **Could not be verified** — the check encountered an error, for example because a required server or service could not be queried.

The summary is a quick status view, not a remediation action. It does not distinguish optional setup from required setup. For example, if MDI is not deployed in the lab, the MDI honeytoken and DNS-transfer checks may show as missing even though the MDI-specific setup is intentionally not in scope.

## Related documentation

- [ASP00 Installation and Setup](ASP00-Setup.md)
- [ASP00 MDI Triggers](ASP00_MDITriggers.md)
- [ASP00 Malicious Tools](ASP00_MaliciousTools.md)
- [ASP00 Backup Share](ASP00_BackupShare.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Internal review: `Invoke-VerifyConfiguration`](../Private/ASP00/Invoke-VerifyConfiguration.ps1)
