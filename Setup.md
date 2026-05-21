# AS2Go Lab Setup Guide

## Overview

This guide covers the initial setup and configuration of an AS2Go (Attack Scenario To Go) lab environment. AS2Go is a PowerShell-based Active Directory attack simulation framework designed for security training, blue team exercises, and detection engineering.

## Minimum Requirements

### Infrastructure
- **Active Directory Domain Controller (DC)** — Windows Server with Active Directory Domain Services
- **Member Server or Client** — Windows Server or Client OS joined to the domain
- **Isolated Network** — No internet access or restricted egress to prevent unintended exposure
- **System Snapshots** — Recommended before and after each lab run

### Software & Prerequisites
- **PowerShell 7.1 or higher** — Installed on all lab systems
- **ActiveDirectory PowerShell Module** — For domain management
- **GroupPolicy PowerShell Module** — For GPO operations
- **AS2Go Module** — Import locally or from PowerShell Gallery

### Permissions
- **Enterprise Admin** or **Domain Admin** credentials
- **Elevated privileges (Run as Administrator)** on the member server/client
- **Local Administrator** rights on systems running simulation phases

### Optional Tools (for advanced phases)
Depending on which attack phases you want to simulate:
- Certify.exe
- Mimikatz.exe
- Rubeus.exe
- NetSess.exe
- PsExec.exe

These tools are placed in the `./Tools/` directory and referenced by various attack functions.

---

## Lab Architecture (Minimum Setup)

```
┌─────────────────────────────────────────┐
│  Domain: contoso.com (or your domain)   │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Domain Controller (DC)          │  │
│  │  • Hosts Active Directory        │  │
│  │  • Hosts DNS                     │  │
│  │  • Hosts ADCS (Certificate Auth) │  │
│  │  • Hosts backup share (optional) │  │
│  └──────────────────────────────────┘  │
│              ↕ (Network)                │
│  ┌──────────────────────────────────┐  │
│  │  Member Server / Client          │  │
│  │  • Lab init execution point      │  │
│  │  • Attack scenario simulator     │  │
│  │  • Telemetry consumer            │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Monitoring (optional)           │  │
│  │  • Defender for Identity (MDI)   │  │
│  │  • Microsoft Sentinel / SIEM     │  │
│  │  • Event Log aggregation         │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

---

## Step-by-Step Setup

### Step 1: Prepare the Environment

1. **Create or use an existing isolated lab domain**
   - Domain name: `contoso.com` (or your test domain)
   - Ensure there is at least one functional Domain Controller

2. **Join a member server or client to the domain**
   - Use a clean image or snapshot
   - Ensure network connectivity to the DC
   - Verify domain membership with `whoami.exe` (should show `DOMAIN\username`)

3. **Verify network connectivity**
   ```powershell
   # From member server/client, verify DC connectivity
   nslookup <DCName>
   nltest /dclist:contoso
   ```

### Step 2: Install PowerShell 7.1+ and Required Modules

1. **Install PowerShell 7.1 or higher**
   ```powershell
   # Download from: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
   # Or via winget:
   winget install Microsoft.PowerShell
   ```

2. **Verify PowerShell version**
   ```powershell
   $PSVersionTable.PSVersion
   # Should be 7.1 or higher
   ```

3. **Install required PowerShell modules**
   ```powershell
   # On the Domain Controller and member server:
   Add-WindowsFeature RSAT-AD-PowerShell
   Add-WindowsFeature RSAT-GroupPolicy-PowerShell
   
   # Or install manually:
   Install-Module ActiveDirectory -Force
   Install-Module GroupPolicy -Force
   ```

4. **Verify module availability**
   ```powershell
   Get-Module -ListAvailable | Select-Object Name, Version
   # Should include: ActiveDirectory, GroupPolicy
   ```

### Step 3: Import the AS2Go Module

**On the member server/client with Enterprise Admin rights:**

#### Option A: Import from Local Path
```powershell
# Navigate to the AS2Go module directory
$AS2GoPath = "C:\Path\To\AS2Go\2026.05.11.755"
Import-Module "$AS2GoPath\AS2Go.psd1" -Force -Verbose

# Verify successful import
Get-Command -Module AS2Go | Select-Object Name
```

#### Option B: Install from PowerShell Gallery
```powershell
Install-Module -Name AS2Go -Scope CurrentUser -Force
Import-Module AS2Go -Force
```

### Step 4: Initialize the Lab Configuration

**Execute on: Member Server / Client (with elevated PowerShell + Enterprise Admin credentials)**

Run the initialization function with default parameters:

```powershell
Initialize-2GoLabConfiguration
```

#### What This Function Does

The `Initialize-2GoLabConfiguration` function presents an interactive menu to configure:

1. **Verify Configuration**
   - Checks that all required AS2Go components are correctly deployed

2. **Break Glass Account**
   - Designates an account excluded from all attack scenarios (e.g., production critical account)

3. **AS2Go Assets**
   - Creates dedicated Active Directory groups (e.g., AS2Go-Admins, AS2Go-Users)
   - Creates organizational units (OUs) for tiered asset management
   - Sets up demo user containers

4. **Demo Users**
   - Creates sample user accounts for privilege escalation and manipulation scenarios

5. **AD Certificate Services (ADCS)**
   - Installs Active Directory Certificate Services on the DC
   - Configures a Certification Authority (CA)
   - Sets up a Web Enrollment Service
   - Creates intentionally vulnerable certificate templates (e.g., ESC1 scenario)

6. **Share**
   - Creates a backup share on the DC
   - Simulates a backup repository with demo backup files
   - Used for reconnaissance and lateral movement scenarios

7. **MDI Triggers**
   - Configures DNS zone transfers (insecure for lab simulation)
   - Sets up honeytokens for Defender for Identity detection tuning

#### Optional Parameters

```powershell
# Custom OU name and scenario abbreviation
Initialize-2GoLabConfiguration -AS2GoOU "SecurityLab" -Scenario "SL"

# Enable logging for troubleshooting
Initialize-2GoLabConfiguration -EnableLogging

# Developer mode (timestamps for testing)
Initialize-2GoLabConfiguration -DeveloperMode
```

#### Follow the Menu in Recommended Order

1. Verify Configuration (validate pre-requisites)
2. Break Glass Account (define protected account)
3. AS2Go Assets (create OUs and groups)
4. Demo Users (create user accounts)
5. ADCS (certificate infrastructure)
6. Share (backup simulation)
7. MDI Triggers (detection tuning)

---

## Step 5: Verify the Lab is Ready

After initialization completes, verify that all components are in place:

```powershell
# Check that AS2Go AD objects were created
Get-ADOrganizationalUnit -Filter "Name -like 'AS2Go*'"

# Check that demo users exist
Get-ADUser -Filter "Name -like 'AS2Go*'" -SearchBase "DC=contoso,DC=com"

# Check that ADCS is installed on the DC
Get-ADCSTemplate | Where-Object { $_.Name -like "*AS2Go*" }

# Check that shares exist on DC
Get-SmbShare -Name "AD-Backup" -CimSession <DCName>

# Check Active Directory groups
Get-ADGroup -Filter "Name -like 'AS2Go*'"
```

---

## Step 6: Run Attack Scenarios

With the lab initialized, you can now run individual attack phases:

```powershell
# List all available phase commands
Get-Command -Module AS2Go | Where-Object { $_.Name -like "Invoke-*Phase*" }

# Start the full guided demo
Start-AS2GoDemo

# Or run individual phases (e.g., Phase 4 - Brute Force)
Invoke-ASPhase04BruteForceAttack

# Non-interactive mode
Start-AS2GoDemo -UnAttended

# Continue from a saved state
Start-AS2GoDemo -Continue

# Enable troubleshooting output
Start-AS2GoDemo -EnableLogging -SkipImages
```

---

## Safety Practices & Best Practices

✓ **Do:**
- Use isolated, non-routed lab networks
- Snapshot systems before each attack run
- Use non-production accounts and test data only
- Restrict internet egress in the lab
- Document each run (time, phases executed, expected alerts, observed alerts)
- Review logs and artifacts in the `CleanUp/` folder after each run
- Test detections and refine incident response playbooks

✗ **Don't:**
- Run AS2Go in production environments
- Run without proper isolation and network segmentation
- Execute without elevated privileges when required
- Share lab credentials or artifacts externally
- Leave lab systems on the internet or publicly accessible

---

## Cleanup and Reset

To remove AS2Go lab artifacts and reset for the next run:

1. **Review generated files**
   ```powershell
   # Navigate to cleanup folder
   Get-ChildItem "$AS2GoPath\CleanUp\" | Select-Object Name, LastWriteTime, Length
   ```

2. **Archive logs and artifacts**
   ```powershell
   # Archive for future reference before cleanup
   Copy-Item "$AS2GoPath\CleanUp\*" -Destination "C:\Labs\Archive\Run-$(Get-Date -Format yyyyMMdd-HHmmss)\" -Recurse
   ```

3. **Restore from snapshot**
   - Restore the VM snapshot created before lab initialization
   - Or manually remove AS2Go objects from Active Directory

---

## Troubleshooting

### Issue: "Computer is not part of a domain"
- **Solution:** Ensure the member server/client is domain-joined. Run `nltest /dclist:contoso` to verify.

### Issue: "ActiveDirectory module not found"
- **Solution:** Install RSAT tools: `Add-WindowsFeature RSAT-AD-PowerShell` (requires elevation on DC)

### Issue: "Access Denied" or permission errors
- **Solution:** Run PowerShell as Administrator. Verify user is a member of Enterprise Admins or Domain Admins.

### Issue: "Module not found" when importing AS2Go
- **Solution:** Verify the path to AS2Go.psd1 and check PowerShell execution policy: `Get-ExecutionPolicy`

### Issue: Initialize function hangs or times out
- **Solution:** Check network connectivity to DC. Verify DNS resolution. Run with `-EnableLogging` for detailed output.

---

## Next Steps

1. ✅ Initialize the lab using `Initialize-2GoLabConfiguration`
2. ✅ Verify all components were created
3. ✅ Snapshot the initialized state
4. ✅ Start monitoring telemetry (Defender, Sentinel, SIEM)
5. ✅ Run `Start-AS2GoDemo` to execute attack scenarios
6. ✅ Observe and validate detections
7. ✅ Document findings and reset from snapshot

---

## Additional Resources

- **AS2Go GitHub:** https://github.com/HerrHozi/AS2Go
- **Author:** Holger Zimmermann
- **Blog:** https://herrhozi.com
- **License:** MIT

---

## Support

For issues, feature requests, or improvements:
- Open an issue on GitHub
- Include reproduction steps, lab setup details, and relevant logs
- Sanitize any sensitive information before sharing
