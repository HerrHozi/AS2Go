################################################################################
######                                                                     #####
######                        Description                                  #####
######                                                                     #####
################################################################################

<#

AS2Go is an acronym for Attack Scenario to Go. 
 
AS2Go is written in PowerShell and goes along the cyber kill chain, 
with stops at Password Spray, Reconnaissance, Privilege Escalation, 
Sensitive Data Access & Exfiltration and Domain Compromise.


The basic idea of AS2Go

My goal is to create expressive and representative Microsoft Defender for Endpoint & Identity alerts 
or rather Microsoft 365 Defender  & Microsoft Sentinel incidents.

Within my current role in the Semperis Breach Preparedness and Response team, 
an additional goal of AS2Go is to increase awareness of how easy it is to 
abuse a vulnerability or misconfiguration to compromise the entire Active Directory.

#>

<#>
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    # Nicht als Admin → neues Fenster als Admin öffnen und Skript erneut starten
    Start-Process pwsh -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit  # Aktuellen (nicht-Admin) Prozess beenden
}
#>

If ($env:AS2GO_EXPORT_PRIVATE -ne 1) {
    ##Requires -RunAsAdministrator
}

$Script:DateFormatLog = "yyyy-MM-dd HH:mm:ss.fff"
$Script:DateFormatSA = "yyyy-MM-dd HH:mm:ss"

$Script:WinVersion = [System.Environment]::OSVersion.Version.ToString()

$ASModulePath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ASModuleTopPath = Split-Path -Path $ASModulePath -Parent
$ASModuleName = $MyInvocation.MyCommand.ScriptBlock.Module.Name

$ASModuleManifest = (Test-ModuleManifest -Path $(join-path $ASModulePath -ChildPath "\$ASModuleName.psd1"))
$ASModuleLastUpdate = $ASModuleManifest.PrivateData.PSData.LastUpdate
$Script:SensitiveInfos = "c:\temp\as2go\daily-work.txt"

$script:AS2GoPublicDir = Join-Path -Path $env:PUBLIC -ChildPath "AS2Go"
$Script:AS2GoLogDir = Join-Path -Path $script:AS2GoPublicDir -ChildPath "Logs"
$Script:AS2GOTempDir = Join-Path -Path $script:AS2GoPublicDir -ChildPath "Temp"
$Script:AS2GOConfigDir = Join-Path -Path $script:AS2GoPublicDir -ChildPath "Config"
$Script:DefautCleanUpFolder = Join-Path -Path $script:AS2GoPublicDir -ChildPath "CleanUp"
$Script:DefautExfiltrationFolder = Join-Path -Path $script:AS2GoPublicDir -ChildPath "Exfiltration"
$Script:AS2GOTicketsDir = Join-Path -Path $script:AS2GoPublicDir -ChildPath "Tickets"

$Script:ASModuleLog = Join-Path -Path $Script:AS2GoLogDir -ChildPath "AS2Go.log"
$Script:ConfigFile = Join-Path -Path $Script:AS2GOConfigDir -ChildPath "AS2Go.json"

$Script:ASTools = Join-Path -Path $ASModulePath -ChildPath "Tools"
$Script:ASPhases = Join-Path -Path $ASModulePath -ChildPath "Phases"
$Script:ASSetup = Join-Path -Path $ASModulePath -ChildPath "LabSetup"
$Script:ASConfig = Join-Path -Path $ASModulePath -ChildPath "Config"

$Global:PathPSCertutil = Join-Path -Path $ASModulePath -ChildPath "Modules\PSCertutil\PSCertutil.psd1"
$Global:PathADCSGoat = Join-Path -Path $ASModulePath -ChildPath "Modules\ADCSGoat\ADCSGoat.psd1"

$Script:AllDomainsDetails = @()
$Script:DoaminTypes = @{}
$Script:ADCS = @{}
[bool]$Script:PoSH7 = $false
[bool]$Script:NotStandAlone = $true
[bool]$Script:MoAD = $false
[bool]$Script:MoGPO = $false
[bool]$Script:MoDNS = $false
[bool]$Script:FileVersionM = $false
[bool]$Script:FileVersionP = $false
[bool]$Script:FileVersionR = $false
[bool]$Script:FileVersionN = $false
[bool]$Script:FileVersionC = $false


If ($PSVersionTable.PSVersion -ge [version]'7.2') {
    $Script:PoSH7 = $true
    # --- Global header color for all Format-Table & Format-List outputs ---
    $PSStyle.Formatting.TableHeader = "`e[90m"   # DarkGray
    $PSStyle.Formatting.FormatAccent = "`e[90m" # DarkGray
    #Cyan → "e[96m"
    #White → "e[97m"
}

$Script:FGCIInfo = [System.ConsoleColor]::Magenta    # Additional info / side details
$Script:FGCMInfo = [System.ConsoleColor]::Yellow       # Main info (instead of Yellow → modern, easy to read)
$Script:FGCSInfo = [System.ConsoleColor]::DarkGray   # Secondary info / less important
$Script:FGCCommand = [System.ConsoleColor]::White      # Commands / executions
$Script:FGCQuestion = [System.ConsoleColor]::Cyan
$Script:FGCInput = [System.ConsoleColor]::Cyan
$Script:FGCDecisionPrompt = [System.ConsoleColor]::Cyan    # Questions / user input
$Script:FGCHighLight = [System.ConsoleColor]::Magenta      # Clear highlight text
$Script:FGCWarning = [System.ConsoleColor]::Cyan      # Warnings (classic Yellow)
$Script:FGCError = [System.ConsoleColor]::Red        # Errors (bright red tone, more visible)

$global:BDSecurePass = ""
$global:BDUser = ""
$global:BDCred = ""

$fgcS = "DarkGray"    # Switch - DarkGray
$fgcC = "Yellow"  # Command
$fgcV = "Cyan"    # Value
$fgcF = "White"
$fgcH = "Yellow" 
$fgcR = "Green"   #result
$fgcG = "Gray"

$Script:ConsoleBGColor = [System.ConsoleColor]::Black
$Script:ConsoleFGColor = [System.ConsoleColor]::Gray

$Script:fgcS = "DarkGray"    # Switch - DarkGray
$Script:fgcC = "Yellow"      # Command
$Script:fgcV = "White"       # Value"DarkCyan"    # Value Blue or Cyan
$Script:fgcF = "White"       # Foreground Color
$Script:fgcR = "Green"       # Result
$Script:fgcHeader = [System.ConsoleColor]::DarkGray

$Script:Yes = "Y"
$Script:No = "N"
$Script:Skip = "S"
$Script:EnableLogging = $false

$Script:RiskyPublishedTemplates = New-Object System.Collections.ArrayList
$Script:AllDomainsDetails = New-Object System.Collections.ArrayList

$Script:Exit = "x"

$Script:PtH = "PtH"
$Script:PtT = "PtT"
$Script:PtC = "ESC1"
$KrA = "K"
$CfM = "M"
$Script:GoldenTicket = "GT"
$Script:InitialStart = "Start"
$Script:PrivledgeAccount = $Script:No

#$tmp = "$ASModulePath\AS2Go.tmp"
$Script:RUBEUS = Join-Path -Path $Script:ASTools -ChildPath "Rubeus.exe"

$Script:Phase04 = "Brute Force or Password Spray"
$Script:Phase05 = "Initial Access"
$Script:Phase06 = "Reconnaissance"
$Script:Phase07 = "Privilege Escalation"
$Script:Phase08 = "Privileged Account Compromise"
$Script:Phase09 = "Reconnaissance with a Privileged Account"
$Script:Phase10 = "Sensitive Data Access"
$Script:Phase11 = "Data Exfiltration"
$Script:Phase12 = "Domain Compromise & Persistence"


$Script:Phase25 = "Misconfigured Certificate Template Attack (ESC1)"
$Script:Phase27 = "Kerberoasting Attack"

$Script:Phase50 = "COMPLETE"

$Script:GroupEA = @()
$Script:GroupSA = @()
$Script:GroupPUG = @()
$Script:GroupDA = @()
$Script:GroupDNSA = @()

$Script:AlternativeUser = @()

$Script:AllDCs = @()

$Script:BestDCs = @{}
$Script:DCsPerDomain = @{}

$Script:departments = (
    # Finance
    @{
        Name      = "Finance & Accounting"
        Positions = @(
            "Finance Manager",
            "Senior Accountant",
            "Accountant",
            "Financial Analyst",
            "Accounts Payable Clerk",
            "Accounts Receivable Clerk"
        )
    },

    # Human Resources
    @{
        Name      = "Human Resources"
        Positions = @(
            "HR Manager",
            "HR Business Partner",
            "HR Administrator",
            "Recruiter",
            "People Operations Specialist"
        )
    },

    # Sales
    @{
        Name      = "Sales"
        Positions = @(
            "Sales Manager",
            "Account Executive",
            "Sales Representative",
            "Business Development Manager",
            "Sales Operations Analyst"
        )
    },

    # Marketing
    @{
        Name      = "Marketing"
        Positions = @(
            "Marketing Manager",
            "Digital Marketing Specialist",
            "Content Manager",
            "SEO Specialist",
            "Marketing Coordinator"
        )
    },

    # Engineering / R&D
    @{
        Name      = "Engineering"
        Positions = @(
            "Engineering Manager",
            "Software Engineer",
            "Senior Software Engineer",
            "Systems Engineer",
            "DevOps Engineer"
        )
    },

    # IT
    @{
        Name      = "Information Technology"
        Positions = @(
            "IT Manager",
            "Systems Administrator (Tier 0)",
            "Cloud Engineer",
            "Network Engineer",
            "IT Support Specialist (Tier 1)"
        )
    },

    # Security
    @{
        Name      = "Cyber Security"
        Positions = @(
            "Security Manager",
            "Security Engineer",
            "SOC Analyst",
            "Incident Response Analyst",
            "IAM Specialist"
        )
    },

    # Consulting / Professional Services
    @{
        Name      = "Consulting"
        Positions = @(
            "Consulting Manager",
            "Senior Consultant",
            "Consultant",
            "Solution Architect"
        )
    },

    # Data & Analytics
    @{
        Name      = "Data & Analytics"
        Positions = @(
            "Data Analyst",
            "Senior Data Analyst",
            "Data Engineer",
            "Business Intelligence Analyst"
        )
    },

    # AI / Automation
    @{
        Name      = "AI & Automation"
        Positions = @(
            "AI Engineer",
            "Machine Learning Engineer",
            "Automation Engineer",
            "AI Solutions Architect"
        )
    },

    # Operations
    @{
        Name      = "Operations"
        Positions = @(
            "Operations Manager",
            "Business Operations Analyst",
            "Process Manager",
            "Service Delivery Manager"
        )
    },

    # Procurement
    @{
        Name      = "Procurement & Purchasing"
        Positions = @(
            "Procurement Manager",
            "Purchasing Specialist",
            "Buyer",
            "Vendor Manager"
        )
    },

    # Legal & Compliance
    @{
        Name      = "Legal & Compliance"
        Positions = @(
            "Legal Counsel",
            "Compliance Manager",
            "Compliance Officer",
            "Risk Analyst"
        )
    }
)

$Script:StartGUID = "{00000000-0000-0000-0000-000000000000}"

#Preference CSE GUID Local users and groups
$Script:CSEGUIDLocalUaG = "{17D89FEC-5C44-4972-B12D-241CAEF74509}"
$Script:ToolGUIDLocalUaG = "{79F92669-4224-476C-9C5C-6EFB4D87DF4A}"

#User Rights Assignment
$Script:CSEGUIDSecurity = "{827D319E-6EAC-11D2-A4EA-00C04F79F83A}"
$Script:ToolGUIDComputerPolicySettings = "{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}"

#Preference CSE GUID Scheduled Tasks
$Script:CSEGUIDScheduledTask = "{AADCED64-746C-4633-A97C-D61349046527}"
$Script:ToolGUIDScheduledTask = "{CAB54552-DEEA-4691-817E-ED4A4D1AFC72}"


##########################################################################

Set-Alias Pause Wait-AS2GoUserInput -Force

$ScriptDir = New-Object System.Collections.ArrayList

if (Test-Path("$ASModulePath\Private")) {
    $PrivatePath = '{0}\Private\*.ps1' -f $ASModulePath
    [VOID]$ScriptDir.Add($PrivatePath)
}
if (Test-Path("$ASModulePath\Public")) {
    $PublicPath = '{0}\Public\*.ps1' -f $ASModulePath
    [VOID]$ScriptDir.Add($PublicPath)
}
if (Test-Path("$ASModulePath\Script")) {
    $ScriptPath = '{0}\Script\*.ps1' -f $ASModulePath
    [VOID]$ScriptDir.Add($ScriptPath)
}

$Scripts = Get-ChildItem -Path $ScriptDir | Select-Object -ExpandProperty FullName

# Load all scripts in the module
foreach ($Script in $Scripts) {
    . $Script
}

#$SearchRecursive = $true
$SearchRootOnly = $false
$PublicScriptBlock = [ScriptBlock]::Create((Get-ChildItem -Path $PublicPath | Get-Content | Out-String))
$PublicFunctionAsts = $PublicScriptBlock.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $SearchRootOnly)
$PublicFunctions = $PublicFunctionAsts.Name

If ($env:AS2GO_EXPORT_PRIVATE -eq 1) {
    $ExportPrivateFunctions = $true
    $Script:EnableLogging = $true
}
else {
    $ExportPrivateFunctions = $false
}

# Export all functions including alias
if ($PublicFunctions) {
    foreach ($Function in $PublicFunctions) {
        $Alias = @()

        #Check if function has an alias
        $AliasFunc = $PublicFunctionAsts | Where-Object { $_.Name -eq $Function -and $_.Body.ParamBlock -and $_.Body.ParamBlock.Attributes } | Select-Object -First 1
        #Check if an alias was found, if it did save the alias name
        if ($AliasFunc) {
            $Alias = $AliasFunc.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' } | ForEach-Object { $_.PositionalArguments.Value } | Where-Object { $_ }
        }

        #If alias exist export function wiht alias
        if ($Alias) {
            Export-ModuleMember -Function $Function -Alias $Alias
        }
        else {
            Export-ModuleMember -Function $Function
        }

    }
}

if ($ExportPrivateFunctions -and $PrivatePath) {
    $PrivateFilePattern = Join-Path -Path $ASModulePath -ChildPath 'Private\*.ps1'
    $PrivateFunctions = Get-Command -CommandType Function |
    Where-Object {
        $_.ScriptBlock -and
        $_.ScriptBlock.File -and
        ($_.ScriptBlock.File -like $PrivateFilePattern)
    } |
    Select-Object -ExpandProperty Name -Unique

    if ($PrivateFunctions) {
        foreach ($Function in $PrivateFunctions) {
            Export-ModuleMember -Function $Function -ErrorAction SilentlyContinue
        }
    }
}
Write-Log -Message "--------------------------------------------------"
Write-Log -Message "Loading AS2go Module"
Write-Log -Message "--------------------------------------------------"

Initialize-AS2GoDirectory -Directory $Script:AS2GoLogDir
Initialize-AS2GoDirectory -Directory $Script:AS2GoTempDir
Initialize-AS2GoDirectory -Directory $Script:AS2GoConfigDir
Initialize-AS2GoDirectory -Directory (Join-Path -Path $script:AS2GoPublicDir -ChildPath "MaliciousTools")
Initialize-AS2GoDirectory -Directory $Script:DefautCleanUpFolder
Initialize-AS2GoDirectory -Directory $Script:DefautExfiltrationFolder
Initialize-AS2GoDirectory -Directory $Script:AS2GOTicketsDir

If (-not (Test-Path -Path $Script:ConfigFile)) {
    copy-item "$ASModulePath\AS2GO.json" -Destination $Script:ConfigFile
}

$LegacySettingNames = @{
    myDC         = 'AS2GoDC'
    myViPC       = 'AS2GoViPC'
    mySAW        = 'AS2GoSAW'
    myAppServer  = 'AS2GoAppServer'
    MySearchBase = 'AS2GoSearchBase'
}
$ConfigData = Get-Content -Path $Script:ConfigFile -Raw | ConvertFrom-Json
$ConfigChanged = $false
foreach ($LegacyName in $LegacySettingNames.Keys) {
    $LegacyEntry = $ConfigData.DefaultParameter.Setting | Where-Object { $_.Name -eq $LegacyName } | Select-Object -First 1
    $CurrentEntry = $ConfigData.DefaultParameter.Setting | Where-Object { $_.Name -eq $LegacySettingNames[$LegacyName] } | Select-Object -First 1
    if ($LegacyEntry -and -not $CurrentEntry) {
        $LegacyEntry.Name = $LegacySettingNames[$LegacyName]
        $ConfigChanged = $true
    }
    elseif ($LegacyEntry -and $CurrentEntry) {
        if (-not $CurrentEntry.Value -and $LegacyEntry.Value) {
            $CurrentEntry.Value = $LegacyEntry.Value
        }
        foreach ($ParameterGroup in $ConfigData.DefaultParameter) {
            $ParameterGroup.Setting = @($ParameterGroup.Setting | Where-Object { $_ -ne $LegacyEntry })
        }
        $ConfigChanged = $true
    }
}
if ($ConfigChanged) {
    $ConfigData | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:ConfigFile -Force
}


<#
$logo = @'
   █████╗ ███████╗██████╗  ██████╗
  ██╔══██╗██╔════╝╚════██╗██╔════╝   
  ███████║███████╗ █████╔╝██║  ███╗ █████╗ 
  ██╔══██║╚════██║██╔═══╝ ██║   ██║ ██ ██║
  ██║  ██║███████║███████╗╚██████╔╝ █████║ 
  ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝  ╚════╝ 
'@ -split "`n"


Write-Host "`n"
$logo | ForEach-Object {
    $line = $_ -replace '█', '█'
    Write-Host $line -ForegroundColor DarkYellow -BackgroundColor Black
}
#>

#Clear-Host
$PiskelPath = Join-Path -Path $ASModulePath -ChildPath "AS2Go.piskel"
$TemporaryPiskelPath = $null
try {
    if (-not (Test-Path -LiteralPath $PiskelPath)) {
        $TemporaryPiskelPath = [System.IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $TemporaryPiskelPath -Encoding UTF8 -ErrorAction Stop -Value '{"modelVersion":2,"piskel":{"name":"AS2Go_7x5","description":"gelb orange","fps":12,"height":11,"width":32,"layers":["{\"name\":\"Layer 1\",\"opacity\":1,\"frameCount\":1,\"chunks\":[{\"layout\":[[0]],\"base64PNG\":\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAALCAYAAAAeEY8BAAAAjElEQVQ4T2NkGGDAOMD2M6A44M8J1/8wB7FY7IbLIYuD5GFyxKhHNgebZ1EsQbcUxAdZgs0QdHEYH5c4rpAm2wHIBiJbisvBRDkAXRGhoAapx+djWBTBzPnfwwCOYsYSRNQTDAF0RxHyLS4HgSyHWYzMJtsBpKYNsh1ATA5Azzm4cgfeKBio8mDACyIA0aWqDKC3fwMAAAAASUVORK5CYII=\"}]}"]}}'
        $PiskelPath = $TemporaryPiskelPath
    }
    Show-PiskelFile -PiskelPath $PiskelPath -addshadow
}
catch {
    <#Do this if a terminating exception happens#>
}
finally {
    if ($TemporaryPiskelPath) {
        Remove-Item -LiteralPath $TemporaryPiskelPath -Force -ErrorAction SilentlyContinue
    }
}


Initialize-ConsoleColors

#Write-Host "`n"
Write-Host "  Description: $($ASModuleManifest.Description) " -ForegroundColor Gray
Write-Host "  Author: HerrHozi | Version: $($ASModuleManifest.Version) | Last Update: $ASModuleLastUpdate | $($ASModuleManifest.Copyright)" -ForegroundColor Gray
Write-Host "`n  get-command " -NoNewline -ForegroundColor DarkYellow
Write-Host "-Module " -ForegroundColor DarkGray -NoNewline
Write-Host "'AS2Go'`n`n" -ForegroundColor DarkCyan


#Write-Host "  Description:     $($ASModuleManifest.Description) " -ForegroundColor Gray
#Write-Host "  Version:         $($ASModuleManifest.Version) | Last Update: $ASModuleLastUpdate | Author: $($ASModuleManifest.Author) " -ForegroundColor Gray
Write-Host "`n  [>] Quick-Start: " -NoNewline -ForegroundColor Gray 

Write-AS2GoOutput -Type Command -NoExtraLines  -Message "Setup-AS2GoDemo"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   New-AS2GoUserSet"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   Start-AS2GoDemo"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   Invoke-ASPhase04BruteForceAttack"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   Invoke-ASPhase07PrivilegeEscalation"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   Invoke-ASPhase12DomainCompromisePersistence"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   ASP07 -EnableLogging -SkipImages -UnAttended -Technique PtT"
Write-AS2GoOutput -Type Command -NoExtraLines  -Message "                   ASP12 -EnableLogging -SkipImages"


Write-host "`n"
Update-WindowTitle "$ASModuleName - $($ASModuleManifest.Version)"
$Script:EnableLogging = $false











