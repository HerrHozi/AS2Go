# ASP00 MDI Triggers

Use **MDI Triggers** in the public `Initialize-AS2GoLab` setup menu only when Microsoft Defender for Identity (MDI) is present in the lab and you want to prepare its related detection scenarios. The menu calls the internal `Invoke-MDITriggers` workflow; users start it through the public setup menu.

The workflow offers DNS zone-transfer settings and honeytoken-account selection. AS2Go does not detect whether MDI is installed or configure MDI itself. Selecting an account here does not register it as a honeytoken in the MDI service.

## Workflow overview

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **MDI Triggers**.
    - `Invoke-MDITriggers` *(internal workflow; repeatable menu)*
      - **DNS & Zone**: review the DNS zones and optionally allow transfers to any server for matching primary zones.
      - **Select HoneyToken**: keep or choose an AD user; save its distinguished name in AS2Go configuration.
      - **Skip**: exit the MDI Triggers menu.

## When to use it

This setup option is relevant only if Microsoft Defender for Identity is deployed in the lab and you intend to demonstrate or validate related detections. If MDI is not present, skip this menu option. It is not required for the other AS2Go setup actions.

## Menu option

```powershell
Initialize-AS2GoLab
```

Complete the setup prompts and select **MDI Triggers**. Choose **DNS & Zone** and/or **Select HoneyToken** as needed, or choose **Skip** to leave the menu. The menu returns after each action so you can run the other option.

## DNS & Zone

The DNS action displays primary zones on the configured logon server and previews the proposed setting with `-WhatIf`. It then asks whether to apply the change; the confirmation defaults to **Yes**. If confirmed, AS2Go sets `SecureSecondaries` to `TransferAnyServer` for DNS zones whose names match the forest root domain. This broad transfer scope is intended for an isolated detection lab and should not be used in production.

The action runs only when the DNS Server PowerShell module is available. If that module is unavailable, the menu displays a warning and skips this DNS change. It does not prevent using the honeytoken option.

Allowing transfers to any server permits DNS zone transfers to any server that can reach the DNS service. Review the affected zones and authorization before confirming, then restore the approved transfer restrictions after the exercise.

## Select HoneyToken

Choose **Previous Honeytoken** to retain the configured account or **New Honeytoken** to open the AD Object Picker and select a user. AS2Go saves that user's distinguished name as the `Honeytoken` setting in its local configuration.

This step only stores the selected account in AS2Go. Configure or register the account as a honeytoken in the MDI service separately, using your lab's MDI procedure. The helper does not perform that service-side configuration.

## Configuration and permissions

The honeytoken distinguished name is stored in `%PUBLIC%\AS2Go\Config\AS2Go.json`. It is written as an ordinary setting, not with the `-DPAPI` option. AS2Go configuration may contain other individually protected settings; DPAPI does not encrypt the entire JSON file. See [ASP00 Installation and Setup](ASP00__Setup.md) for the common configuration details.

Applying the DNS change requires the DNS Server PowerShell module, connectivity to the configured DNS server, and permissions to change zone settings. Selecting the honeytoken requires directory read access to browse and select a user; it does not change the user's AD attributes.

## Related documentation

- [ASP00 Installation and Setup](ASP00__Setup.md)
- [Security Policy and authorized use](../SECURITY.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Internal workflow: `Invoke-MDITriggers`](../Private/ASP00/Invoke-MDITriggers.ps1)
- [DNS zone settings helper](../Private/ASP00/Set-AS2GoDnsZoneConfiguration.ps1)
- [Honeytoken selection helper](../Private/ASP00/Set-HoneyToken.ps1)
