# ASP10 Sensitive Data Access Guide | Invoke-ASPhase10AccessSensitiveData

*Kill-chain Phase 10 — enumerate shares, read a simulated backup database from an unprotected share, and open an application-server console to read a plaintext password file, and understand why password storage and unmonitored shares turn ordinary file access into a compromise.*

![ASP10 Sensitive Data Access phase](../Assets/Images/ASP10.png)

> For explicitly authorized lab environments only. Run from an initialized AS2Go module session.

---

## 1. What this workflow does

[Invoke-ASPhase10AccessSensitiveData](../Public/Invoke-Phase10AccessSensitiveData.ps1) walks through the sensitive-data-access demonstration:

| Step | Action | Details |
|---|---|---|
| 0 | Confirm the phase | Decision prompt; in `-SafeMode` the phase ends here after the overview |
| 1 | Share enumeration | `Get-SmbShare` against the server hosting the configured backup share |
| 2 | Plant a simulated `ntds.dit` | Writes a recursive listing of the AS2Go module files to the backup share as a fake Active Directory database (directory-listing text, **not** a real `ntds.dit`) |
| 3 | Enumerate share content | Displays the backup-share contents — including the just-planted fake database staging area |
| 4 | Prepare the sample password file | Creates the `SensitiveInfos` file on the configured application server via its administrative share if absent: `"AS2Go simulated sensitive information. Use xyz for application purposes. No real credentials are stored in this file."` |
| 5 | Open the remote console | Starts `PsExec.exe \\<AppServer> -accepteula cmd.exe`; copies `more "<SensitiveInfos>"` to the clipboard and displays it for manual use (the command is not typed automatically) |

The lab uses simulated backup data and a simulated plaintext password file only — no real credentials and no real `ntds.dit` database are involved. Run the phase with the account appropriate to the scenario, not the Enterprise Admin session used for setup.

---

## 2. Why this phase matters

- **Backup shares accumulate the copies nobody owns**: a fake `ntds.dit` staged on an unprotected backup share mirrors how a real AD database copy is exported and left accessible for exfiltration (Phase 11). If a share holds a database export, domain secrets leave the domain protection perimeter.
- **The remote console is a lateral bridge**: `PsExec` against the application server demonstrates the exact sequence an attacker uses after obtaining local-admin credentials — enumerate, reach `ADMIN$`/`C$`, open a shell, inspect disk state. No exploit code is involved; the phase only uses access the environment already grants.
- **Plaintext password files**: the `SensitiveInfos` sample is the everyday reality of password leftovers in text files next to applications. Security lesson for participants: passwords should never be stored in plaintext — anyone with local admin on the host can read whatever the service account leaves on disk.
- **The security lesson in one line**: monitor share access and PsExec-style remote execution, constrain who can write backup shares, and keep credentials out of plaintext — every step of this phase fails when those controls exist.

---

## 3. Safe Mode and unattended execution

With `-SafeMode`, ASP10 displays its overview and skips the actions. In unattended mode, it runs the phase automatically unless Safe Mode is enabled. The PsExec command prompt may still open and require operator interaction.

---

## 4. Working notes from the lab

### 4.1 The fake `ntds.dit` is a listing, not a database

The planted file is a recursive listing of AS2Go module files via `Get-ChildItem | Out-File` into `<BackupShare>\ntds.dit`. The output looks like structured data worth stealing while keeping the lab free of a real AD database. Participants compare share contents before and after the write.

### 4.2 The PsExec step is interactive by design

ASP10 copies the `more` command to the clipboard (`Set-Clipboard`, with a `clip.exe` fallback) but does not type it into the remote console. The operator performs the read manually — so the walkthrough stays auditable and the remote-console interaction remains visible in the demo narrative.

### 4.3 The sample file is created with `-NoClobber`

Existing content at the `SensitiveInfos` path is never overwritten; the file is only written when absent. Re-running the phase on an already-prepared lab leaves the original file untouched.

---

## 5. What defenders observe (Blue Team notes)

- **Share enumeration pattern**: SMB share enumeration (`Get-SmbShare`, or similar discovery) from a workstation account against server targets — correlate with Event 5140/5145 (network share access) and the same source host that later runs Phase 11 exfiltration.
- **Staged database-like files on backup shares**: a new `ntds.dit`-shaped file on a share with no associated backup job is the signal. Watch file-create events on backup paths; an AD database export belongs only on a domain controller's own filesystem — any other location is anomalous.
- **PsExec footprint**: Event 7045 (service install: `PSEXESVC`), Event 4624 Type 3 from the same origin, and child processes on the target whose parent is `PSEXESVC.exe` instead of `services.exe` — a ready-made detection. Sysmon Event 1 raises the fidelity further.
- **Plaintext password leftovers**: the simulated password file mirrors the most common real-world finding. Scheduled discovery scans (DLP, share crawlers, simple pattern scripts) catch password-patterned text files at scale — this is the same lesson `Get-AS2GoSettings` teaches when it shows plaintext values in configuration.
- **The hardening lesson**: tiered share permissions (no broad-group write on backup folders), monitoring on `ADMIN$`/`C$` access, PsExec usage restricted to known admin hosts, and no plaintext credentials on disk — every technique in this phase depends on one of those gaps being open.

---

## 6. Command quick reference

```powershell
# 1) Enumerate shares on the backup-share host (as the workflow does)
Get-SmbShare -ComputerName <BackupServer>

# 2) Read the backup-share contents (the simulated ntds.dit lives here)
Get-ChildItem "\\<BackupServer>\<BackupShare>" -Recurse | Out-Host

# 3) The remote read the demo copies to the clipboard:
more "<SensitiveInfos-Path>"

# 4) Defender view — share access, PsExec install, and logons on the target
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 5140, 5145, 4624, 7045 } `
    -MaxEvents 100 -ComputerName <Server-FQDN> |
    Select-Object TimeCreated, Id, Message | Format-List
```

The workflow itself requires no manual commands — run `Invoke-ASPhase10AccessSensitiveData` (or `Start-AS2GoDemo` menu option *Sensitive*) and confirm the phase.

---

## 7. Related

- Phase diagram: [ASP10.html](../Phases/ASP10.html)
- Share setup and tools preparation: [ASP00__Setup.md](ASP00__Setup.md), [ASP00_BackupShare.md](ASP00_BackupShare.md), [ASP00_MaliciousTools.md](ASP00_MaliciousTools.md)
- The next step in the kill chain (moving staged data out): Phase 11 — Exfiltrate Sensitive Data
- MITRE ATT&CK: Network Share Discovery [T1135](https://attack.mitre.org/techniques/T1135/), Remote Services [T1021](https://attack.mitre.org/techniques/T1021/), Unsecured Credentials [T1552](https://attack.mitre.org/techniques/T1552/)
