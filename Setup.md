# AS2Go Lab Setup Guide

## Scope and Safety

AS2Go (Attack Scenario to Go) demonstrates known Active Directory attack techniques for security training and detection validation. Use it only in an isolated, explicitly authorized lab with non-production accounts and sample data. Do not run it in production.

Live setup changes Active Directory, certificate services, DNS settings, and file shares, depending on the selected options. Some scenarios change permissions, establish persistence, encrypt files, or restart systems. Take coordinated snapshots before configuration and before running scenarios.

Editing this guide or reviewing the source does not require a domain-joined computer. Offline preview also does not require domain membership. Live initialization checks domain membership and normally stops on a computer outside the domain.

## 1. Prepare the Lab

| Component | Purpose |
| --- | --- |
| Active Directory test domain with at least one DC and working DNS | Directory services and lab targets |
| Domain-joined Windows member server or workstation | Victim machine and preferred execution point for initial configuration |
| Additional workstation for SAW/PAW scenarios | Administrative activity used by selected scenarios |
| AD Certificate Services | Required for certificate-based scenarios; configurable through setup |
| Semperis Lightning, Defender for Identity, Defender for Endpoint, or a SIEM | Optional monitoring for validating detections |

Use an isolated network with restricted egress. Obtain installation packages before disconnecting the lab, or use controlled access during preparation. The member computer must resolve the lab domain and controllers through lab DNS. Remote setup requires the applicable management connections, including PowerShell remoting and SMB for backup-share setup.

For live initialization, open an elevated PowerShell session using a lab account in Domain Admins or Enterprise Admins. The initializer checks that group membership; Enterprise Admin privileges are recommended for full configuration. Local elevation alone does not grant directory permissions. Later scenarios may use different identities: follow their prompts rather than running every phase as the setup administrator.

Check actual computer membership rather than relying on the username shown by `whoami.exe`:

```powershell
Get-CimInstance -ClassName Win32_ComputerSystem |
    Select-Object Name, Domain, PartOfDomain

# Replace the example domain with your lab domain.
Resolve-DnsName -Name 'contoso.com'
nltest.exe /dsgetdc:contoso.com
```

## 2. Install PowerShell and Management Tools

The module manifest declares PowerShell 7.4 as its minimum version. Install a supported PowerShell 7 release meeting this requirement on the execution computer and start `pwsh.exe` for AS2Go.

Install the Windows management tools providing `ActiveDirectory`, `GroupPolicy`, and `DnsServer`. These are Windows/RSAT components, not modules to install through `Install-Module ActiveDirectory` or `Install-Module GroupPolicy`.

On Windows Server, install the relevant features from elevated **Windows PowerShell**:

```powershell
Install-WindowsFeature -Name RSAT-AD-PowerShell, GPMC, RSAT-DNS-Server
```

`RSAT-DNS-Server` installs the `DnsServer` PowerShell module and DNS Manager on the Windows Server where you run AS2Go. In Server Manager, select **Manage > Add Roles and Features**, then under **Features** select **Remote Server Administration Tools > Role Administration Tools > DNS Server Tools**. On a server with Desktop Experience, open the DNS MMC snap-in from **Server Manager > Tools > DNS** or run `dnsmgmt.msc`. These steps install management tools only. [Microsoft RSAT documentation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools)

On a supported Windows client, use **Optional Features** to install:

- RSAT: Active Directory Domain Services and Lightweight Directory Services Tools
- RSAT: Group Policy Management Tools
- RSAT: DNS Server Tools

Follow Microsoft's [RSAT installation instructions](https://learn.microsoft.com/en-us/windows-server/administration/install-remote-server-administration-tools) for your Windows edition and platform. See also [Installing PowerShell on Windows](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows).

In PowerShell 7, verify availability and importability before live setup:

```powershell
$PSVersionTable.PSVersion
Get-Module -ListAvailable -Name ActiveDirectory, GroupPolicy, DnsServer
Import-Module -Name ActiveDirectory -SkipEditionCheck -ErrorAction Stop
Import-Module -Name GroupPolicy -SkipEditionCheck -ErrorAction Stop
Import-Module -Name DnsServer -SkipEditionCheck -ErrorAction Stop
```

## 3. Import AS2Go

Keep the complete local module structure, including `Public`, `Private`, `Modules`, and `LabSetup`:

```powershell
# Replace this path with your local AS2Go folder.
$AS2GoPath = 'C:\Labs\AS2Go'
Import-Module -Name (Join-Path -Path $AS2GoPath -ChildPath 'AS2Go.psd1') -Force
Get-Command -Module AS2Go | Select-Object Name
```

Alternatively, install the published package:

```powershell
Install-Module -Name AS2Go -Scope CurrentUser
Import-Module -Name AS2Go -Force
```

The published package may differ from this checkout. Inspect its commands and parameters with `Get-Command` and `Get-Help`.

Import creates runtime directories below `$env:PUBLIC\AS2Go` and copies the bundled configuration to `Config\AS2Go.json` if that file does not already exist. Reimporting preserves an existing runtime configuration. Review saved hostnames, domains, accounts, UPN suffixes, and paths for your lab; bundled values may refer to the author's environment.

## 4. Review the Workflow Offline (Optional)

Use `-Preview` to review setup and demo steps offline:

```powershell
Initialize-AS2GoLab -Preview
Start-AS2GoDemo -Preview

# Print the demo workflow without interactive navigation.
Start-AS2GoDemo -Preview -UnAttended
```

Preview returns before live function initialization, AD queries, configuration writes, and tool execution. Module-import directory/configuration initialization still occurs. Preview shows source descriptions and planned commands; it does not validate connectivity, permissions, runtime choices, or detection results. `-Simulation` and `-DeveloperMode` are not substitutes for preview.

## 5. Initialize the Lab

On the domain-joined victim machine, use the elevated administrative PowerShell 7 session:

```powershell
Initialize-AS2GoLab

# Optional custom naming and logging:
Initialize-AS2GoLab -AS2GoOU 'SecurityLab' -Scenario 'SL' -EnableLogging
```

The setup command also has the alias `Setup-AS2GoDemo`. Use `Get-Command Initialize-AS2GoLab -Syntax` to inspect its parameters. The UPN suffix comes from the saved `LastUPNSuffix` setting. `-DeveloperMode` enables logging and can use timestamp-based naming during live setup.

Review the requirements confirmation and discovered forest, domain, controller, and account information. Work through the menu in its displayed order, revisiting **Verify Config** afterward:

| Menu option | Action and considerations |
| --- | --- |
| Verify Config | Reviews the current lab configuration and reports individual results and query failures. See [Verify Readiness](#6-verify-readiness). |
| Malicious Tools | Selects the tools folder, disables Defender real-time monitoring, adds a folder exclusion, attempts to copy archives, and guides manual extraction. These protection changes require explicit lab authorization and may be blocked by managed security policy. |
| BGA | Stores the selected break-glass account for exclusion by scenario logic. This does not replace isolation or snapshots. |
| SAW | Selects or records the Secure Access Workstation hostname; it does not provision or harden a workstation. |
| AS2Go Assets | Creates dedicated tiering OUs and AD groups. Review the naming and scope. |
| Demo Users | Creates demonstration accounts. Review the selected OU and account details. |
| ADCS | Offers CA/Web Enrollment setup and intentionally vulnerable certificate templates, including ESC1 demonstrations. |
| Share | Creates `AD-Backup` on the configured DC, copies sample backup files, and saves its UNC path as `BackupShare`. Requires remote administration and share access. |
| MDI Triggers | Configures lab DNS zone transfers and honeytoken-related settings for detection exercises. |
| Quit | Returns from setup. |

Selected phases use `Certify.exe`, `Mimikatz.exe`, `Rubeus.exe`, `NetSess.exe`, and `PsExec.exe`. Archives may be absent from your checkout. See [Tools/README.md](Tools/README.md) for sources and tested versions. Place required executables in the configured tools folder. Setup offers `$env:PUBLIC\AS2Go\MaliciousTools` as its default destination, separate from the repository's `Tools` folder.

Coordinate endpoint-protection settings with the lab owner and detection objectives. The tools menu changes Defender settings after confirmation; setup also displays protection-related prerequisites. Record approved changes and restore them after the exercise. Do not weaken protections on production systems.

## 6. Verify Readiness

Reopen **Verify Config** from the setup menu. Review each result and warning individually.

- **Local settings and files** — Checks for expected executables in the configured tools folder and sample files on the backup share. Displays the saved break-glass account and MDI honeytoken separately.
- **Workstation and directory** — Checks TCP port 5985 on the configured Secure Access Workstation and inventories tiering OUs, groups, and demo accounts in the current domain.
- **AD CS and DNS** — Lists enterprise CAs and checks for the ESC1 template by name, for example `AS2Go ESC1`. Checks the Web Enrollment feature on the selected forest-root domain controller and reports DNS zone transfer settings from the setup logon server.

The final message indicates that the review finished. A failed query produces a warning and the next check group continues.

Use read-only checks as appropriate:

```powershell
Get-ADDomain | Select-Object DNSRoot, DistinguishedName
Get-ADOrganizationalUnit -Filter "Name -eq 'AS2Go'"
Get-ADGroup -Filter "Name -like '*AS2Go*'"

# Replace the hostname with the configured lab DC.
Get-ChildItem -LiteralPath '\\DC01.contoso.com\AD-Backup'
```

Adjust filters for custom OU/scenario names. Verify demo users in their configured OU; names need not begin with `AS2Go`. For certificate scenarios, review the CA, enrollment service, and intended template status in the ADCS menu. Confirm monitoring receives telemetry, then snapshot the prepared lab.

## 7. Run an Authorized Scenario

Review help and expected impact before live execution:

```powershell
Get-Command -Module AS2Go -Name 'Invoke-ASPhase*'
Get-Help -Name Start-AS2GoDemo -Full

# Start the interactive live workflow after preparation.
Start-AS2GoDemo

# Troubleshooting output or continuation from the saved stage:
Start-AS2GoDemo -EnableLogging -SkipImages -SkipClearHost
Start-AS2GoDemo -Continue
```

Individual phases are available, for example `Invoke-ASPhase04BruteForceAttack`. Commands perform live actions when `-Preview` is absent. Use `-UnAttended` only after reviewing and authorizing the workflow: it suppresses prompts where possible and does not make execution harmless.

Record phases, timestamps, expected alerts, observed telemetry, and failures. Use only fake sensitive data for data-access demonstrations. Phase 10 uses the sample-file path defined by `$Script:SensitiveInfos` in `AS2Go.psm1`.

## Runtime Files and Reset

Default runtime locations below `$env:PUBLIC\AS2Go`:

| Folder | Contents |
| --- | --- |
| `Config` | Persisted `AS2Go.json` settings |
| `Logs` | Module logs, including `AS2Go.log` |
| `Temp` | Temporary working files |
| `MaliciousTools` | Default tools destination offered by setup |
| `CleanUp` | Generated artifacts for review and cleanup |
| `Exfiltration` | Output used by exfiltration demonstrations |
| `Tickets` | Ticket-related artifacts |

Configured paths may differ. Archive required evidence securely before resetting. Logs and artifacts can contain sensitive lab information; sanitize them before sharing.

Deleting runtime files does not undo AD, DNS, AD CS, GPO, share, or endpoint-protection changes. Restore coordinated lab snapshots, or review and reverse each change manually. Confirm protection settings and exclusions are restored as intended. Include the execution computer's persisted configuration in the reset plan.

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| Computer is not part of a domain | Check `Win32_ComputerSystem.PartOfDomain`. Join the execution computer to the test domain for live initialization; use preview for offline review. |
| Management module unavailable | Install the corresponding Windows/RSAT component and verify import in PowerShell 7. |
| `ERROR: The 'DnsServer' PowerShell module is not installed.` | On the Windows Server running AS2Go, run `Install-WindowsFeature -Name RSAT-DNS-Server` in elevated Windows PowerShell. Open a new PowerShell 7 session and run `Get-Module -ListAvailable -Name DnsServer`. |
| Access denied | Check local elevation, Domain Admins/Enterprise Admins membership, and target permissions. Reopen the session after changing group membership. |
| Remote setup or share creation fails | Check lab DNS, selected controller, remoting/SMB connectivity, firewall rules, and target permissions. |
| External tool or archive missing | Check configured tools path, filenames, manual extraction, and quarantine events. |
| Unexpected lab names or stale paths | Review `$env:PUBLIC\AS2Go\Config\AS2Go.json`; importing preserves an existing file. |
| Unsupported setup parameter | Inspect `Get-Command -Name Initialize-AS2GoLab -Syntax` and installed version. Source help may contain legacy examples. |
| Verification completes but assets are missing | Inspect each inventory section and verify the service or object independently. |
| PKINIT returns `KDC_ERR_PADATA_TYPE_NOSUPP` | See [Troubleshooting PKINIT and KDC_ERR_PADATA_TYPE_NOSUPP](https://herrhozi.com/2026/11/10/troubleshooting-pkinit-kdc-err-padata-type-nosupp/). |

For more detail, use setup's `-EnableLogging` switch and review the runtime logs. Report issues through [AS2Go on GitHub](https://github.com/HerrHozi/AS2Go) with sanitized reproduction steps, module version, and relevant errors.
