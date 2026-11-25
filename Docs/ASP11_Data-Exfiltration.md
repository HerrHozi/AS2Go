# ASP11 | Data Exfiltration

![ASP11 data exfiltration phase](../Assets/Images/ASP11.png)

ASP11 demonstrates copying accessible AS2Go backup-share files to a local folder over SMB. The lab uses simulated backup data. It does not extract credentials from a real Active Directory database or upload files to an external service.

Complete the shared preparation in [ASP00 Installation and Setup](ASP00__Setup.md) first. Run the phase with the account appropriate to the scenario, not the Enterprise Admin session used for setup.

## **Menu option**

Start `Start-AS2GoDemo` and select **Exfil**. The phase can also be started directly with `Invoke-ASPhase11ExfiltrateSensitiveData` (alias: `ASP11`).

## What the phase does

When you continue, ASP11 creates the configured local destination folder if needed, copies files from the configured backup share over SMB, and lists `.dit` files found in the destination. The default destination is `$env:PUBLIC\AS2Go\Exfiltration`.

The phase copies files to the local host only. It does not send them outside the lab, parse the simulated `.dit` file, or extract credentials. The operation requires read access to the backup share and enough local access to create and write to the destination folder.

## Safe Mode and unattended execution

With `-SafeMode`, ASP11 displays its overview and skips the copy operation. In unattended mode, it copies the files automatically unless Safe Mode is enabled.

## Requirements

- A configured and reachable AS2Go backup share with read access for the current account.
- SMB connectivity between the execution host and the share.
- Write access to the configured local exfiltration folder.

See [ASP00 Backup Share](ASP00_BackupShare.md) for share setup and [ASP10 Sensitive Data Access](ASP10_Sensitive-Data-Access.md) for the preceding sample-data workflow.

## Related documentation

- [ASP00 Installation and Setup](ASP00__Setup.md)
- [ASP00 Backup Share](ASP00_BackupShare.md)
- [ASP10 Sensitive Data Access](ASP10_Sensitive-Data-Access.md)
- [ASP11 phase walkthrough](../Phases/ASP11.html)
