# ASP00 Backup Share Setup

Use the **Share** option in the public `Initialize-AS2GoLab` setup menu to prepare the `AD-Backup` SMB share on a domain controller for an authorized AS2Go lab. The menu calls the private `Invoke-BackUpShare` workflow, which calls the private `New-BackUpShare` helper; users start the public setup command and select the menu option.

The workflow is:

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **Share**.
    - `Invoke-BackUpShare` *(internal workflow)*
      - Ask for confirmation and let the operator select a domain controller in the current domain.
      - `New-BackUpShare` *(internal helper)*
        - Create or reuse `C:\temp\as2go` on the selected controller.
        - Grant `Domain Admins` NTFS **Modify** access.
        - Create the `AD-Backup` SMB share with **Change** access for `Domain Admins` if it does not already exist.
      - Copy the configured sample files and write a recursive directory listing to `ntds.dit` in the share.
      - Save `\\<DC>\AD-Backup` as `BackupShare` and the controller name as `AS2GoAppServer`.

## Before you begin

Complete the shared setup and authorization guidance in [ASP00 Installation and Setup](ASP00__Setup.md) and [the security policy](../SECURITY.md). Run the setup on the prepared, domain-joined Windows Server in the administrative sign-in used for lab setup.

`Initialize-AS2GoLab` checks for an elevated process and verifies membership in Domain Admins or Enterprise Admins. The setup screen recommends Enterprise Admin privileges for full configuration. The function checks availability of the Active Directory, Group Policy, and DNS Server modules; Active Directory tools are needed for the domain and controller selection used by the Share workflow. The share workflow also needs PowerShell remoting, SMB/CIM connectivity, and local administrative/share-management rights on the selected domain controller.

The operation creates or reuses `C:\temp\as2go` on the selected controller, grants the `Domain Admins` group NTFS **Modify** access, and creates the `AD-Backup` SMB share with **Change** access for that group. The workflow copies the configured sample content and stores the share UNC path in AS2Go configuration. This modifies the lab controller; confirm the selected target and use an isolated authorized environment.

## Menu option

```powershell
Initialize-AS2GoLab
```

The command opens the AS2Go environment configuration menu after its prerequisite checks. `Setup-AS2GoDemo` is an alias. Select **Share** in the menu to run the backup-share workflow.

The command's switches are documented once in [ASP00 Installation and Setup - Shared command switches](ASP00__Setup.md#shared-command-switches). There is no public command or share-specific parameter that directly invokes `New-BackUpShare`.

## Parameters

There are no parameters specific to selecting or creating the backup share. The menu drives target selection and confirmation. `Initialize-AS2GoLab` has general setup parameters; use the shared switch reference linked above for their declared names and behavior.

The `-Scenario` value, when supplied to `Initialize-AS2GoLab`, is passed to the share workflow and included in the share description. The setup function validates it to contain no whitespace. The default value is `AS2Go`.

## Output

The menu workflow displays the current configured backup-share path, asks for confirmation, and lets you select the target domain controller. On success, it displays the target and the contents of `\\<DC>\AD-Backup`, then saves that UNC path as the `BackupShare` setting and the controller name as `AS2GoAppServer`.

The private `New-BackUpShare` helper does not return a dedicated result object. It writes the target's non-special SMB share names, paths, and descriptions to the console and AS2Go log. The calling workflow copies files from the configured `ShareContent` directory and creates a file named `ntds.dit` from a recursive directory listing; these are simulated sample data, not a copy of the domain controller's real database.

## Required permissions

`Initialize-AS2GoLab` requires an elevated process and verifies that the current account is in Domain Admins or Enterprise Admins. Its initial screen recommends Enterprise Admin privileges for full setup. The share creation itself uses remote PowerShell and CIM operations, so the executing identity also needs local administrative/share-management rights on the selected domain controller and network access for remoting, SMB, and CIM.

The workflow grants `Domain Admins` NTFS Modify access and SMB Change access to the created share. Those are permissions assigned to share users; they are not a substitute for the caller's required remote administration rights.

## Safety and operational impact

- **State changes:** Creates `C:\temp\as2go` if missing, sets a `Domain Admins` NTFS access rule, and creates `AD-Backup` if that share name is not already present. The caller then copies simulated files and updates AS2Go configuration.
- **Existing share:** If `AD-Backup` already exists, the helper skips `New-SmbShare`; it does not update the existing share's path, description, or share permissions. It still applies the NTFS rule to `C:\temp\as2go`.
- **Confirmation:** The workflow asks whether to proceed before target selection. You can decline or exit the selection prompt before the remote operation.
- **Preview:** `-Preview` returns before the setup menu and does not create the share. `-SafeMode` is declared on `Initialize-AS2GoLab`, but this function does not use it to change the Share menu action; do not treat it as protection or a dry run for share creation.
- **Cleanup:** Review the share and its contents after the exercise. The public `Remove-AS2GoLab -Share` workflow asks for confirmation, then removes the SMB share and recursively deletes its backing `C:\temp\as2go` folder. Preserve any needed lab files before cleanup.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| Setup reports that the process must run as Administrator. | The PowerShell process is not elevated. | Reopen PowerShell with **Run as administrator** using the approved setup account. |
| The setup function stops after checking group membership. | The current account is not in Domain Admins or Enterprise Admins, or membership could not be verified. | Use the authorized lab setup account and verify its group membership and directory connectivity. |
| The Share operation reports an access or remoting error. | WinRM, CIM, SMB connectivity, or local administrative/share-management rights on the target DC are missing. | Verify the selected DC, network/firewall access, remoting configuration, and the setup account's rights on that controller. |
| The share is created but sample files are missing. | The higher-level copy step failed, or the configured `ShareContent` source is unavailable. | Review the error output and log, then verify the AS2Go installation's `ShareContent` directory and write access to `\\<DC>\AD-Backup`. |

## Related documentation

- [ASP00 Installation and Setup](ASP00__Setup.md)
- [Security Policy and authorized use](../SECURITY.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Public cleanup function: `Remove-AS2GoLab`](../Public/Remove-AS2GoLab.ps1)
- [Share workflow: `Invoke-BackUpShare`](../Private/ASP00/Invoke-BackUpShare.ps1)
- [Share creation helper: `New-BackUpShare`](../Private/ASP00/New-BackUpShare.ps1)
