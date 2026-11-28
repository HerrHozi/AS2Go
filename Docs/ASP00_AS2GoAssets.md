# ASP00 AS2Go Assets

Use the **AS2Go Assets** option in the public `Initialize-AS2GoLab` setup menu to create the tiered Active Directory structure for an authorized AS2Go lab. The internal `Initialize-AS2GoAssets` function is called by the menu; users do not start it directly.

On a first-time setup, the function creates this OU hierarchy. The `AS2Go` name can be changed with the public setup command's `-AS2GoOU` parameter; the parent OU defaults to the current domain root and can be changed in the menu prompt.

- `OU=AS2Go` *(or the configured `-AS2GoOU` name)*
  - `OU=Demo Accounts`
  - `OU=Tier 0 Assets`
    - `OU=T0 Accounts`
    - `OU=T0 Groups`
    - `OU=T0 Devices`
    - `OU=T0 ServiceAccounts`
    - `OU=T0 Servers`
  - `OU=Tier 1 Assets`
    - `OU=T1 Accounts`
    - `OU=T1 Groups`
    - `OU=T1 Devices`
    - `OU=T1 ServiceAccounts`
    - `OU=T1 Servers`
  - `OU=Tier 2 Assets`
    - `OU=T2 Accounts`
    - `OU=T2 Groups`
    - `OU=T2 Devices`
    - `OU=T2 ServiceAccounts`
    - `OU=T2 Servers`

The function also creates the following security groups inside each tier's `Groups` OU. These are the default names when `-Scenario` is `AS2Go`; a custom scenario value replaces `AS2Go` in each name.

- `OU=T0 Groups`
  - `SG-AS2Go-T0-Admins` — Global security group; added to the current domain's **Domain Admins** group.
  - `UG-AS2Go-T0-Enterprise` — Universal security group; added to the forest root's **Enterprise Admins** group.
- `OU=T1 Groups`
  - `SG-AS2Go-T1-Admins` — Global security group; added to **Server Operators**.
- `OU=T2 Groups`
  - `SG-AS2Go-T2-Admins` — Global security group for the Tier 2 admin/help desk role.
  - `SG-AS2Go-Users` — Global security group for the AS2Go user role.

The workflow also adds the Tier 2 admin and user groups to the local **Administrators** group on the computer running AS2Go.

## Before you begin

Follow the shared installation, authorization, and Quick Start guidance in [ASP00 Installation and Setup](ASP00-Setup.md). Run lab preparation in the Enterprise Admin sign-in on the domain-joined Windows Server. Do not run this setup against production Active Directory.

The public initializer checks that PowerShell is elevated and that the current account is a member of Domain Admins or Enterprise Admins. The full assets workflow also changes privileged group membership across the current domain and forest root. Use an Enterprise Admin account with rights to create and update OUs, groups, users, and computers, change OU permissions, and update the local Administrators group on the execution server. The module requires PowerShell 7.4 and the Active Directory management tools. The setup initializer also checks for Group Policy and DNS Server modules; see the parent setup guide for installation details.

The menu uses the current domain and its selected preferred domain controller. The assets workflow lets you keep the domain root as the parent OU or select/create a different parent OU. It creates directory objects, modifies group memberships and permissions, and may move existing privileged groups. Review the prompts and selected scope before confirming.

## Menu option

```powershell
Initialize-AS2GoLab
```

`Setup-AS2GoDemo` and `ASP00` are aliases of the public initializer. After it completes its prerequisite checks, select **AS2Go Assets** from **AS2Go - Environment Configuration**. This menu choice calls `Initialize-AS2GoAssets` internally.

## Parameters

There are no parameters specific to the **AS2Go Assets** menu choice. The public initializer accepts general setup parameters; their shared behavior is documented in [ASP00 Installation and Setup](ASP00-Setup.md#command-switch-reference).

| Public setup parameter | Default | Effect on AS2Go Assets |
|---|---|---|
| `-AS2GoOU` | `AS2Go` | Names the top-level AS2Go OU created under the selected parent OU. |
| `-Scenario` | `AS2Go` | Adds the scenario label to group names and object metadata. It cannot contain whitespace. |

The selected domain controller and UPN suffix are obtained by the setup workflow; `Initialize-AS2GoLab` does not expose them as parameters.

## Output

The workflow writes progress and results to the console and does not return a dedicated result object. On a first-time setup, it creates the AS2Go OU (default `AS2Go`) and `Demo Accounts` OU, followed by **Tier 0 Assets**, **Tier 1 Assets**, and **Tier 2 Assets**. Each tier contains OUs for accounts, groups, devices, service accounts, and servers.

It creates scenario-named security groups for Tier 0, Tier 1, and Tier 2 administration and user roles, creates demo computer and service-account objects, and records selected OU and group names in AS2Go configuration. It adds selected AS2Go groups to local or built-in privileged groups as part of the lab setup. If you confirm the later prompt, it also moves selected existing privileged groups into the Tier 0 Groups OU.

## Required permissions

The public setup initializer verifies Domain Admins or Enterprise Admins membership. Creating the lab objects and completing the group and ACL changes requires the corresponding directory permissions. Full forest setup requires rights to modify the Enterprise Admins group in the forest root; use the Enterprise Admin sign-in for this workflow. The function also adds selected groups to the local Administrators group on the computer running AS2Go, so the process must be elevated there.

## Safety and operational impact

- **Directory changes:** Creates OUs, groups, users, and computer accounts; updates some configuration values; modifies privileged group memberships and OU permissions.
- **Privileged access:** The generated Tier 0 groups are nested into Domain Admins and, for the enterprise group, Enterprise Admins. The Tier 1 administrator group is nested into Server Operators. Tier 2/user groups are added to local Administrators on the AS2Go execution server.
- **Existing privileged groups:** A confirmation prompt controls whether selected administrative groups are moved to the Tier 0 Groups OU. Review the list and forest/domain scope before accepting.
- **Existing tier structure:** If a Tier 0, Tier 1, or Tier 2 Assets OU already exists, the function switches to checking/creating scenario groups and returns before the remaining first-time local-group, privileged-group, and ACL steps. Do not assume a rerun reapplies every setup action.
- **Preview and rollback:** The private assets action has no separate `-WhatIf` or dry-run mode. `Initialize-AS2GoLab -Preview` previews the outer setup flow and returns before running the menu action; it does not preview the exact AD changes. Take and verify a lab snapshot before execution.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| Setup refuses to continue because the process is not elevated. | PowerShell was not started as Administrator. | Reopen PowerShell with elevation in the authorized Enterprise Admin session. |
| Group membership verification fails or the menu does not start. | The account is not in Domain Admins/Enterprise Admins, or AD connectivity/module access is unavailable. | Verify the setup identity, domain connectivity, and Active Directory RSAT module; review the setup output. |
| An existing group is reported as not matching the expected AS2Go group. | A group with the scenario name already exists with a different role, scope, category, or AS2Go marker. | Review the existing group's purpose and membership before changing it. Choose a distinct scenario label if appropriate; do not delete or repurpose production groups. |
| Some local or privileged group changes fail. | The current identity lacks rights on the local server or target domain/forest group. | Check elevation and the account's delegated/Enterprise Admin rights, then verify each reported group change in the lab. |
| The OU picker returns no parent or the workflow stops. | The selected OU was cancelled, is not available in the current domain, or the account cannot create/read OUs there. | Reopen the menu, select a valid parent OU in scope, and confirm directory permissions. |

## Related documentation

- [ASP00 Installation and Setup](ASP00-Setup.md)
- [ASP00 Backup Share](ASP00_BackupShare.md)
- [Security Policy and authorized use](../SECURITY.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
