################################################################################
######                                                                     #####
######                        Description                                  #####
######                                                                     #####
################################################################################

<#

AS2Go is an acronym for Attack Scenario To Go. 
 
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

$Global:PathPSCertutil = Join-Path -Path $Script:ASSetup -ChildPath "PSCertutil\PSCertutil.psd1"
$Global:PathADCSGoat = Join-Path -Path $Script:ASSetup -ChildPath "ADCSGoat\ADCSGoat.psd1"

$Script:AllDomainsDetails = @()
$Script:DoaminTypes = @{}
$Script:ADCS = @{}
[bool]$Script:PoSH7 = $false


If ($PSVersionTable.PSVersion.Major -ge 7) {
    $Script:PoSH7 = $true
    # --- Global header color for all Format-Table outputs ---
    $PSStyle.Formatting.TableHeader = "`e[90m"   # DarkGray
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

$Script:PtH = "H"
$Script:PtT = "T"
$PtC = "C"
$KrA = "K"
$CfM = "M"
$Script:GoldenTicket = "GT"
$Script:InitialStart = "Start"
$Script:PrivledgeAccount = $Script:No

#$tmp = "$ASModulePath\AS2Go.tmp"
$Script:RUBEUS = Join-Path -Path $Script:ASTools -ChildPath "Rubeus.exe"

$Script:Phase04 = "Brute Force Or Pw Spray"
$Script:Phase05 = "User Account Compromised"
$Script:Phase06 = "Reconnaissance"
$Script:Phase07 = "Privilege Escalation"
$Script:Phase08 = "Priviledge Account Compromised"
$Script:Phase09 = "Reconnaissance with Priviledge Account"
$Script:Phase10 = "Access Sensitive Data"
$Script:Phase11 = "Exfiltrate Data"
$Script:Phase12 = "Domain Compromised & Persistence"

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

Set-Alias Pause Invoke-NextStep -Force

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

Invoke-AS2GoDirectory -Directory $Script:AS2GoLogDir
Invoke-AS2GoDirectory -Directory $Script:AS2GoTempDir
Invoke-AS2GoDirectory -Directory $Script:AS2GoConfigDir
Invoke-AS2GoDirectory -Directory (Join-Path -Path $script:AS2GoPublicDir -ChildPath "MaliciousTools")
Invoke-AS2GoDirectory -Directory $Script:DefautCleanUpFolder
Invoke-AS2GoDirectory -Directory $Script:DefautExfiltrationFolder
Invoke-AS2GoDirectory -Directory $Script:AS2GOTicketsDir

If (-not (Test-Path -Path $Script:ConfigFile)) {
    copy-item "$ASModulePath\AS2GO.json" -Destination $Script:ConfigFile
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

Show-PiskelFile -PiskelPath (Join-Path -Path $ASModulePath -ChildPath "AS2Go.piskel") -addshadow

#Write-Host "`n"
Write-Host "  Description: $($ASModuleManifest.Description) " -ForegroundColor Gray
Write-Host "  Author: HerrHozi | Version: $($ASModuleManifest.Version) | Last Update: $ASModuleLastUpdate | $($ASModuleManifest.Copyright)" -ForegroundColor Gray
Write-Host "`n  get-command " -NoNewline -ForegroundColor DarkYellow
Write-Host "-Module " -ForegroundColor DarkGray -NoNewline
Write-Host "'AS2Go'`n`n" -ForegroundColor DarkCyan


#Write-Host "  Description:     $($ASModuleManifest.Description) " -ForegroundColor Gray
#Write-Host "  Version:         $($ASModuleManifest.Version) | Last Update: $ASModuleLastUpdate | Author: $($ASModuleManifest.Author) " -ForegroundColor Gray
Write-Host "`n  [>] Quick-Start: " -NoNewline -ForegroundColor Gray 

Write-HighlightedCode  -code "Initialize-AS2GoLabConfiguration"
Write-HighlightedCode  -code "                   Invoke-ASPhase04BruteForceAttack"
Write-HighlightedCode  -code "                   Invoke-ASPhase07PrivilegeEscalation"
Write-HighlightedCode  -code "                   Invoke-ASPhase12DomainCompromisePersistence"
Write-HighlightedCode  -code "                   Start-AS2GoDemo"
Write-HighlightedCode  -code "                   ASP07 -EnableLogging -SkipImages"
Write-HighlightedCode  -code "                   ASP12 -EnableLogging -SkipImages -AS2GoDemo"


Write-host "`n"
$host.ui.RawUI.WindowTitle = "$ASModuleName - $($ASModuleManifest.Version)"



