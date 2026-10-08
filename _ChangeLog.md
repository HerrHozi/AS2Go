# Change Log

```Text
Author:          Holger Zimmermann | <zimmermann.holger@live.de>
Current Version: 2026.10.7.871
Last Update:     2026-10-07
```

- Version 2026.10.7.871
  - TBD

- Version 2026.8.10.1104
  - Updated Function Invoke-ADCSSetup | added option for new prefix

- Version 2026.6.3.1125
  - Added variable $Script:Skip

- Version 2026.5.22.1018
  - Minor Bug fixes

- Version 2026.5.22.663
  - Updated Functions New-BackDoorUser & Invoke-NewAS2GoAssets | add error handling for insufficient privileges
  - added IntelliSense for private AS2Go Functions

- Version 2026.5.21.1342
  - Uploaded to Github & PS Gallery

- Version 2026.5.21.957
  - Started Updating Function Invoke-PassTheTicketAttack 

- Version 2026.5.20.583
  - Added Function Start-ExportDPAPIMasterKey
  - Added Function Invoke-GoldenTicket
  - Added Function Clear-ExfiltrationFolder

- Version 2026.5.19.839
  - replace variables by $script:xxxx

- Version 2026.5.18.1200
  - Added Function Invoke-MaliciousToolsSetup

- Version 2026.5.18.1133
  - Added / Updated Functions regarding GPT Manipulation - Add Scheduled Tasks & User Right Assignment
  - Remove unused files & functions from Core-Functions

- Version 2026.5.15.1181
  - Added Requirements to function Initialize-AS2GoLabConfiguration
  - Added / Updated Functions regarding GPT Manipulation - Add members to built-in group

- Version 2026.5.13.567
  - Renamed Functions -KeyValue to -ASConfig
  - Added Function Invoke-PrivilegesEscalationViaLocalSystem
  - Updated Function Show-DecisionPrompt | Updated for REPEAT

- Version 2026.5.12.1072
  - Updated Function 

- Version 2026.5.11.755
  - Updated Functions Invoke-KerberoastingAttack & Start-KerberoastingAttack

- Version 2026.5.8.619
  - Updated Functions regarding ESC1, add selection for Built-in Account

- Version 2026.5.7.1034
  - Updated Functions regarding ESC1, add selection for decicated Account

- Version 2026.5.7.570
  - Moved ADSA config & log file to $env:public
  - Updated Function Get-SessionOnDC  

- Version 2026.5.6.809
  - Exclude unused Function

- Version 2026.5.6.502
  - Updated Function Get-KerberosTGT
  - Updated help on public Functions and README.md

- Version 2026.5.5.1019
  - Updated Function Invoke-PrivilegeEscalationViaESC1 & Request-PfxWithCertify 

- Version 2026.5.5.896
  - Updated Function Restart-VictimMachines

- Version 2026.5.5.532
  - Updated Functions New-UserManipulation & Start-UserManipulation

- Version 2026.5.4.1360
  - Updated Functions for Ransomware Attack | Start-Phase12DomainCompromise, Invoke-FileEncryption, Invoke-FakeRansomwarePopUp, New-RansomwareAttack

- Version 2026.4.30.1114
  - Moved Log File to $env:LOCALAPPDATA\AS2Go\Logs

- Version 2026.3.17.1034
  - Update Function Start-PasswordSprayAttack

- Version 2026.3.17.575
  - Added Function Set-AttackScope
  - Updated Function Start-PasswordSprayAttack, includes samaccountname as password
  - replaced Write-BlockFont with own logo

- Version 2026.3.16.772
  - Updated Function Start-PasswordSprayAttack (paralell processing) & New-PasswordSprayAttack

- Version 2026.2.26.773
  - Updated Function New-BackDoorUser | added to all Builtin Admins Groups

- Version 2026.2.25.1057
  - Added Functions Invoke-GroupManipulation & Start-GroupManipulation

- Version 2026.2.25.741
  - Replace ADCSGoat (0.0.4) & PSCertUtil (0.0.3) with newer versions

- Version 2026.2.24.795
  - Updated Function New-BackDoorUser | add to Enterprise Admins in Root Domain
  - Added Functions Get-UPNSuffix & Set-UPNSuffix

- Version 2026.2.24.685
  - Updated Functions Invoke-Phase12DomainCompromisePersistence

- Version 2026.2.24.534
  - Updated Functions Invoke-Phase10AccessSensitiveData & Invoke-Phase11ExfiltrateSensitiveData

- Version 2026.2.23.1100
  - Updated Function Get-AS2GoSettings

- Version 2026.2.23.416
  - Added Function Invoke-MDITriggers
  - Updated Select-ADObject

- Version 2026.2.20.887
  - Added Function Set-BreakGlassAccount

- Version 2026.2.20.668
  - Added Function New-TargetBase

- Version 2026.2.20.603
  - Added Function Get-BestDomainController

- Version 2026.2.19.1054
  - Updated Function Invoke-NewAS2GoAssets & Invoke-VerifyConfiguration
  - Added Functions Get-TieringAssets & Get-DemoAccounts 

- Version 2026.2.19.864
  - Added Function Invoke-BackUpShare & New-BackUpShare
  - Updated Function Start-PasswordSprayAttack

- Version 2026.2.19.670
  - Updated Function New-DemoAccount | Added Option for sub OUs Location, Department or both.

- Version 2026.2.18.821
  - Updated Function New-DemoAccount | Switched to paralell processing

- Version 2026.2.18.732
  - Updated Module ADCSGoat & added Publish-AGCertifcateTemplate

- Version 2026.2.18.535
  - Added Function Install-ADCSEnrollementServices
  - Updated Function Add-ADCSForAS2Go, Get-ADCSCertifcateTemplates, Invoke-ADCSSetup

- Version 2026.2.17.1324
  - Updated Functions Invoke-ForestOverview, Get-NumberOfDCs, Set-BestDomainController, Get-DomainPWDetails | error Handling if no DC is available

- Version 2026.2.16.1115
  - Added Functions Get-ADCSEnterpriseCA & Get-ADCSEnrollmentServices

- Version 2026.2.14.802
  - Added Function Invoke-ForestOverview, Get-NumberofDCs & Set-BestDomainController

- Version 2026.2.13.582
  - Code Clean Up & first preview

- Version 2026.2.13.97
  - Updated Function Invoke-ADCSSetup

- Version 2026.2.12.1348
  - Integrated PowerShell Modules ADCSGoat & PSCertutil | dedicated Server

- Version 2026.2.11.765
  - Updated Function Initialize-ActiveDirectoryConfig
  - Updated Function Select-ADObject & New-DemoAccount

- Version 2026.2.10.972
  - Updated Function Initialize-ActiveDirectoryConfig & New-DemoAccount

- Version 2026.2.9.945
  - Updated Function Invoke-DemoAccounts

- Version 2026.2.9.845
  - Added Functions Invoke-DemoAccounts, New-DemoAccount & Add-RandomUsersToAccountOperators 

- Version 2026.2.6.953
  - Replace $MyFunction by $CurrentFunction

- Version 2026.2.6.853
  - Updated Function Invoke-DNSZoneUpdate

- Version 2026.2.6.559
  - Updated Function Set-DenyPermission

- Version 2026.2.3.769
  - Added Public Function Initialize-ActiveDirectoryConfig
  - Added Functions Invoke-NewAS2GoAssets, Disable-ADOUInheritance & Set-DenyPermissions

- Version 2026.2.2.1086
  - Added Function Select-OU
  - Added Function Show-DecisionPrompt

- Version 2025.10.26.710
  - Updated and Renamed Function Write-ASMessage to Invoke-Output

- Version 2025.10.21.1103
  - Added Function Write-ASMessage

- Version 2025.10.21.653
  - Added Function Invoke-Phase12DomainCompromisePersistence

- Version 2025.10.17.1010
  - Updated Functions Start-ReconnaissanceExtended & Start-Reconnaissance

- Version 2025.10.3.1107
  - Added Function Write-ASWarning, Write-ASError & Write-ASHeader

- Version 2025.10.2.710
  - Updated Function New-PasswordSprayAttack & Start-PasswordSprayAttack

- Version 2025.10.1.801
  - Updated Posh Module for function Invoke-Phase09ReconnaissancePriviledged
  - Added Function Get-DomainType

- Version 2025.9.30.1279
  - Updated Functions Start-Reconnaissance, Get-ForestInfo & Get-PriviledgeGroupMembers

- Version 2025.9.30.762
  - Updated $Script Variable
  - Add input parameter Tools

- Version 2025.9.30.567
  - Updated PoSH Module for functions New-PrivilegeEscalationRecommendation & Start-KerberoastingAttack

- Version 2025.9.29.645
  - Updated PoSH Module for step Invoke-Phase07PrivilegeEscalation

- Version 2025.3.12.567
  - Updated PoSH Module for step Invoke-Phase06Reconnaissance

- Version 2025.3.10.567
  - Updated PoSH Module for step Invoke-Phase04BruteForceAttack

- Version 2025.3.8.567
- converted from PoSH Script to PoSH Module

## internal - update via git

```PowerShell
$Host.UI.RawUI.WindowTitle = "GIT - Uploading AS2Go"
$dir = "$env:OneDriveConsumer\Programming\GitHub\AS2Go"
Set-Location $dir
git pull
git status
git add -A
git commit -m 'Version 2026.5.21.1342 is out - see also readme.md or changeLog.md'
git push

Publish-Module -Exclude '.git\*' -Name .\AS2Go.psd1
