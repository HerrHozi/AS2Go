# ASP00 Malicious Tools

Use **Malicious Tools** in the public `Initialize-AS2GoLab` setup menu to prepare a local folder for the external tools used by AS2Go scenarios. The menu calls the internal `Initialize-AS2GoTools` function; users start the workflow through the public menu.

## Workflow overview

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **Malicious Tools**.
    - `Initialize-AS2GoTools` *(internal workflow)*
      - Confirm the operation, then confirm the default tools folder or browse to another folder.
      - Save the selected path in the AS2Go `Tools` configuration setting.
      - Disable Microsoft Defender real-time monitoring and add the selected folder as a Defender exclusion.
      - Copy `AS2Go-Tools_v3.zip` and `README.md` into the confirmed destination folder.
      - The operator manually extracts the ZIP in that folder and confirms the extraction in the console.

This setup action does not create or modify Active Directory objects.

## Before you begin

Complete the shared installation, authorization, and setup guidance in [ASP00 Installation and Setup](ASP00-Setup.md). Run the menu on the prepared lab server from the elevated setup session. The setup requires local administrative rights for Defender configuration. Defender settings may also be controlled by organizational policy.

The selected folder will contain credential-access and other security assessment utilities. Use this workflow only on an isolated, explicitly authorized lab system. Coordinate the Defender changes with the lab owner and monitoring objectives before proceeding.

## Menu option

```powershell
Initialize-AS2GoLab
```

Complete the setup prompts and select **Malicious Tools**. Confirm the displayed destination or choose another folder. AS2Go copies `AS2Go-Tools_v3.zip` into that confirmed folder. You must extract the ZIP there manually, then confirm in the console that extraction is complete. The default destination is `$env:PUBLIC\AS2Go\MaliciousTools`. The setup command switches are documented in [ASP00 Installation and Setup](ASP00-Setup.md#command-switch-reference).

## What the workflow prepares

| Item | Behavior |
|---|---|
| Tools folder | Stores the selected path in the local AS2Go configuration as `Tools`. |
| Microsoft Defender | Runs `Set-MpPreference -DisableRealtimeMonitoring $true` and adds the selected folder using `Add-MpPreference -ExclusionPath`. |
| Archive and instructions | Copies `AS2Go-Tools_v3.zip` and `README.md` from the module's `Tools` directory into the folder confirmed by the operator. |
| Extraction | AS2Go opens the destination folder. The operator manually extracts the password-protected ZIP in that folder, then confirms completion in the console. The displayed archive password is `HerrHozi!`. |

The function prints a table of tool filenames, tested versions, build dates, and SHA-256 values. It does not calculate or compare hashes during setup. See [Tools/README.md](../Tools/README.md) for tool project and download references.

The archive is expected to provide these executables:

| Executable | Tool | Tested release |
|---|---|---:|
| `NetSess.exe` | NetSess | 2.0.0.46 |
| `Mimikatz.exe` | Mimikatz | 2.2.0.0 |
| `Rubeus.exe` | Rubeus | 2.3.3.0 |
| `Certify.exe` | Certify | 2.0.0.0 |
| `PsExec.exe` | PsExec | 2.4.3 |

AS2Go scenarios look for these tools in the configured tools folder. The archive's tested versions can differ from current upstream releases; use the source links and notes in `Tools/README.md` when preparing a replacement set.

## Operational impact and cleanup

- Defender real-time monitoring is disabled on the computer running setup. The function does not re-enable it when setup ends.
- The tools folder is added as a Defender exclusion. The function does not remove that exclusion later.
- Selecting a different destination changes the saved `Tools` path used by AS2Go scenarios.
- The operator is responsible for extracting the ZIP into the confirmed destination and confirming completion in the console.
- The archive and extracted executables may be quarantined or blocked by endpoint security or managed policy. Do not bypass organizational controls without authorization.

After the lab exercise, restore Defender real-time monitoring and remove the folder exclusion according to the lab's approved process. Review the configured `Tools` path and retain or remove the archive and extracted files as required by the lab cleanup plan. Restoring these local settings does not undo any other lab changes.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| Defender setting change fails | PowerShell is not elevated, Defender cmdlets are unavailable, or policy manages the setting. | Verify local elevation and the Defender platform; coordinate policy changes with the lab owner. |
| Source archive or README is missing | The module's `Tools` directory is incomplete. | Check the module installation and the files listed in [Tools/README.md](../Tools/README.md). |
| Copy operation fails | The destination is unavailable or access is denied. | Select a writable local folder and confirm that the archive and README exist in the source directory. |
| Scenario reports a missing executable | The archive has not been extracted, or the configured tools folder differs from the extraction destination. | Extract the archive into the configured folder and review the `Tools` path in the AS2Go configuration. |

## Related documentation

- [ASP00 Installation and Setup](ASP00-Setup.md)
- [External tool sources and tested versions](../Tools/README.md)
- [Security Policy and authorized use](../SECURITY.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Internal workflow: `Initialize-AS2GoTools`](../Private/ASP00/Initialize-AS2GoTools.ps1)
