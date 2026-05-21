function Initialize-2GoLabConfiguration {
    <#
    .SYNOPSIS
    Initializes AS2Go lab setup with tiering assets, demo users, DNS Zone, ADCS installation & creation of an smb share.

    .DESCRIPTION
    The Initialize-AS2GoLabSetup function prepares the Actice Directory through a 
    menu-driven interface to configure and deploy AS2Go lab components. It enables the 
    creation of dedicated AS2Go Active Directory groups, organizational units, and 
    demo users aligned with a tiering model.

    The function enables zone transfers for lab simulation purposes. 
    
    It installs and configures Active Directory Certificate Services (AD CS), 
    including one Certification Authority (CA) and one Web Enrollment Service.

    Additionally, a file share is created on the Domain Controller to simulate a 
    backup repository containing fake backup files for assessment and testing scenarios.

    .PARAMETER AS2GoOU
    Specifies the name of the Active Directory Organizational Unit (OU) to be created or used for AS2Go 
    resources. Default value is "AS2Go".
    
    Type: String
    Default: "AS2Go"
    Aliases: None
    Required: False

    .PARAMETER Scenario
    Specifies the scenario or abbreviation to be used for naming Active Directory objects. Default value 
    is "AS2Go".
    
    Type: String
    Default: "AS2Go"
    Aliases: None
    Required: False

    .PARAMETER UPNSuffix
    Specifies the User Principal Name (UPN) suffix for user accounts created in the Active Directory domain.
    Default value is "@mrhozi.com".

    Type: String
    Default: "@mrhozi.com"
    Aliases: None
    Required: False

    .PARAMETER EnableLogging
    Specifies whether to enable detailed logging for the function execution. When enabled, all operations 
    are logged to the designated log file.
    
    Type: Switch
    Default: $false
    Aliases: None
    Required: False

    .PARAMETER DeveloperMode
    Specifies whether to enable developer mode for testing and debugging. When enabled, logging is 
    automatically enabled and a timestamp-based OU name is used for testing purposes.
    
    Type: Switch
    Default: $false
    Aliases: None
    Required: False

    .EXAMPLE
    Initialize-AS2GoLabSetup

    Description: Runs the function with default parameters, launching an interactive menu to select 
    the Active Directory setup scope.

    .EXAMPLE
    Initialize-AS2GoLabSetup -AS2GoOU "SecurityTier" -Scenario "ST"

    Description: Initializes Active Directory setup using "SecurityTier" as the OU name and "ST" as 
    the acronym for naming objects.

    .EXAMPLE
    Initialize-AS2GoLabSetup -EnableLogging

    Description: Runs the function with logging enabled for operational tracking and troubleshooting.

    .EXAMPLE
    Initialize-AS2GoLabSetup -DeveloperMode

    Description: Runs the function in developer mode with automatic logging enabled and timestamp-based 
    OU naming for testing purposes.

    .EXAMPLE
    Initialize-AS2GoLabSetup -AS2GoOU "AS2Go" -UPNSuffix "@contoso.com" -EnableLogging

    Description: Initializes Active Directory setup with a custom UPN suffix and logging enabled.

    .INPUTS
    System.String
        AS2GoOU parameter accepts string input for the organizational unit name.
    
    System.String
        acronym parameter accepts string input for the naming abbreviation.
    
    System.String
        UPNSuffix parameter accepts string input for the UPN suffix.

    System.Management.Automation.SwitchParameter
        EnableLogging and DeveloperMode are switch parameters (true/false).

    .OUTPUTS
    None. The function performs configuration operations and provides interactive menu-driven user 
    interface output. Results are logged to the designated log file when logging is enabled.

    .NOTES
    Author: AS2Go Team
    Version: 1.0.0
    Last Updated: 2026-02-06

    Prerequisites:
    - The function requires elevated privileges (Domain Admin equivalent)
    - ActiveDirectory and GroupPolicy PowerShell modules must be installed
    - The script must be executed on a Domain Controller
    - Required modules are pre-checked before execution

    Menu Options:
    - Tiering Assets: Creates dedicated AS2Go Active Directory groups and organizational units
    - AD Backup Share: Creates AD-Backup share with CHANGE permission for Domain Admins
    - Domain (current): Applies configuration only to the current domain
    - OU: Allows selection of a specific organizational unit for configuration
    - Skip: Skips the Active Directory setup

    Related Functions:
    - Invoke-NewAS2GoAssets
    - Setup-ADBackupShare
    - Setup-ADDomain
    - Confirm-PoSHModuleAvailabliy
    - Write-Log
    - Get-FunctionName

    .LINK
    https://learn.microsoft.com/en-us/powershell/module/activedirectory/

    .LINK
    https://learn.microsoft.com/en-us/powershell/scripting/developer/help/writing-help-for-powershell-functions
    #>

    param(
        [string] $AS2GoOU = "AS2Go", 
        [ValidatePattern('^\S+$')]
        [string] $Scenario = "AS2Go",
        [Switch] $EnableLogging,
        [Switch] $DeveloperMode
    )

    If ($DeveloperMode) {
        $EnableLogging = $true
        $Script:TimeStamp = (Get-Date).ToString('HHmmss')
        If ($Scenario -eq "AS2Go") {
            $AS2GoOU = $Script:TimeStamp
            $Scenario = $Script:TimeStamp
        }
    }
    
    $CurrentFunction = Get-FunctionName

    Write-Log -Message "."
    Write-Log -Message "<< -- UniversalTime [UTC]"
    Write-Log -Message " "
    Write-Log -Message "##################################################################"
    Write-Log -Message "#                                                                #"
    Write-Log -Message "     Starting Module $ASModuleName / $CurrentFunction [Version $($ASModuleManifest.Version)] "
    Write-Log -Message "#                                                                #"
    Write-Log -Message "##################################################################"
    Write-Log -Message " "
    Write-Log -Message "    >> Using PowerShell version $($PSVersionTable.PSVersion.tostring())"
    Write-Log -Message " "
    
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Clear-Host
    
    # --- Global header color for all Format-Table outputs ---
    $PSStyle.Formatting.TableHeader = "`e[90m"   # DarkGray #Cyan → "e[96m" #White → "e[97m"
    Set-NewBackgroundColor -BgC $Script:ConsoleBGColor -FgC $Script:ConsoleFGColor 

    [bool]$Script:ADCSEnterpriseCAMissing = $true
    [bool]$Script:ADCSEnrollmentServiceMissing = $true
    [bool]$Script:ADCSASGoCTemplatesMissing = $true

    $Script:ErrorForestInfo = $null
    $Script:ExistingOUs = @{}
    $Script:LogonServer = ""

    Invoke-Output -Type Header -Message "Initial AS2Go Environment Configuration"
    Invoke-Output -Type H1 -Message "Requirements for the initial AS2Go lab configuration:`n"
    Invoke-output -Type Bullet -Message "At least a single-domain Active Directory environment."
    Invoke-output -Type Bullet -Message "At least one Domain Controller (DC)."
    Invoke-Output -Type Bullet -Message "At least one domain-joined victim machine, such as a server or workstation."
    Invoke-output -Type Bullet -Message "Initial configuration should preferably be executed on the victim machine."
    Invoke-output -Type Bullet -Message "Administrative privileges are required."
    Invoke-output -Type Bullet -Message "Enterprise Admin privileges are recommended for full configuration."
    Invoke-output -Type Bullet -Message "AS2Go stores malicious tools, configuration files, logs, and related data under: " -Tm $script:AS2GoPublicDir
    
    $title = "Confirm the requirements" 
    $Message = "Proceed with the initial AS2Go environment configuration?"
 
    $Options = @(
        [pscustomobject] @{ Label = "&Yes, all requirements are fulfilled"; Help = "Yes."; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&Continue, but NOT all requirements are fulfilled (not recommended)"; Help = "e.g. Setup the ADCS could fail"; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&Quit"; Help = "Quit & return"; Value = $Script:No }
    )

    $answer = Show-DecisionPrompt -Title $title -Message $message -default 2 -Options $Options

    if ($answer -eq $Script:No) {
        Write-Log -Message "User chose to quit the initial configuration. Exiting..."
        return
    }

    If ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
        $FQDN = (Get-ADDomain).DNSRoot
    }
    else {
        Invoke-Output -Type Error -Message "Computer '$env:COMPUTERNAME' is not part of a domain"
        $FQDN = '<FQDN>'
        If (-Not $DeveloperMode) { return }
    }
    
    $UPNSuffix = Get-ASConfig -Setting "LastUPNSuffix"
    $Script:LogonServer = Get-LogonServerFQDN

    Invoke-ForestOverview 

    $currentuser = whoami.exe
    $samaccountname = $currentuser.Split("\")[-1]

    Invoke-output -Type Bullet -Message "Scenario:             " -TM $Scenario
    Invoke-output -Type Bullet -Message "Target UPN Suffix:    " -TM $UPNSuffix
    Invoke-output -Type Bullet -Message "Target Domain:        " -TM $FQDN
    Invoke-output -Type Bullet -Message "Target OU:            " -TM "$FQDN/$AS2GoOU"
    Invoke-output -Type Bullet -Message "Current Logon Server: " -TM $Script:LogonServer
    Invoke-output -Type Bullet -Message "Current User:         " -TM $currentuser

    Get-ADPrincipalGroupMembership -Identity $samaccountname | Select-Object @{N = 'MemberOf'; E = { $_.samaccountname } } | Out-Host

    
    $MoAD = Confirm-PoSHModuleAvailabliy -PSModule "ActiveDirectory"
    $MoDNS = Confirm-PoSHModuleAvailabliy -PSModule "DnsServer"

    try {
        Import-Module $Global:PathADCSGoat -NoClobber -ErrorAction Stop
        Invoke-Output -T Bullet -M "Imported PowerShell module: " -TM "ADCSGoat"
    } 
    catch {
        Invoke-Output -T Error -M "Unable to import PowerShell module $Global:PathADCSGoat"
    }

    try {
        Import-Module $Global:PathPSCertutil -NoClobber -ErrorAction Stop
        Invoke-Output -T Bullet -M "Imported PowerShell module: " -TM "PSCertutil"
    } 
    catch {
        Invoke-Output -T Error -M "Unable to import PowerShell module $Global:PathPSCertutil"
    }


    if ($MoAD -eq "failed" -or $MoDNS -eq "failed") {
        [bool]$PreCheckFailed = $true
    }

    If ($PreCheckFailed -eq $true) {
        Write-host "`n  [>] Please acknowledge the missing requirement(s) by pressing ENTER ... " -ForegroundColor $Script:FGCWarning -NoNewline
        $confirmed = Read-Host
        Write-Log -Message "        >> Confirmed the warning with - $confirmed"
        If (-not $DeveloperMode) {
            If ($MoAD -eq "failed") {
                return    
            }
        }
    }


    $title = "AS2Go - Environment Configuration"
    $message = "Follow the listed order for optimal execution."

    $Options = @(
        [pscustomobject] @{ 
            Label = "&Verify Config"; 
            Help  = "Validate that all required AS2Go Active Directory configurations are in place."; 
            Value = "Verify" 
        },
        [pscustomobject] @{ 
            Label = "Malicious &Tools"; 
            Help  = "Define folder for Malicious Tools and extracts tools, like Certify, Rubeus, etc."; 
            Value = "MaliciousTools" 
        },
        [pscustomobject] @{ 
            Label = "&Break Glass Account"; 
            Help  = "Define the break-glass account. This account is excluded from all attack scenarios."; 
            Value = "BGA" 
        },     
        [pscustomobject] @{ 
            Label = "&AS2Go Assets"; 
            Help  = "Create dedicated AS2Go Active Directory groups and organizational units."; 
            Value = "Assets" 
        },
        [pscustomobject] @{ 
            Label = "&Demo Users"; 
            Help  = "Create demo accounts for user manipulation scenarios."; 
            Value = "DemoUsers" 
        },
        [pscustomobject] @{ 
            Label = "AD&CS"; 
            Help  = "Set up Active Directory Certificate Services, including intentionally vulnerable templates (e.g., ESC1)."; 
            Value = "ADCS" 
        }, 
        [pscustomobject] @{ 
            Label = "&Share"; 
            Help  = "Create a share for simulated Active Directory backups on a Domain Controller."; 
            Value = "Share" 
        },
        [pscustomobject] @{ 
            Label = "&MDI Triggers"; 
            Help  = "Configure settings to enable Microsoft Defender for Identity (MDI) specific detections, including DNS zone transfers and honeytokens."; 
            Value = "MDI" 
        },
        [pscustomobject] @{ 
            Label = "&Quit"; 
            Help  = "Exit the AS2Go environment configuration."; 
            Value = "Q" 
        }
    )

    $repeat = $Script:Yes
    do {

        $decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
        Clear-Host
        
        switch ($decision) {
            "Share" {
                Invoke-BackUpShare
            }
            "MaliciousTools" {
                Invoke-MaliciousToolsSetup
            }
            "ADCS" {
                Invoke-ADCSSetup -CTPreFix $Scenario
            }
            "Assets" {
                Invoke-NewAS2GoAssets -AS2GoOU $AS2GoOU -Scenario $Scenario -UPNSuffix $UPNSuffix -Server $Script:LogonServer
            }
            "DemoUsers" {
                Invoke-DemoAccounts -AS2GoOU $AS2GoOU -Scenario $Scenario -UPNSuffix $UPNSuffix -Server $Script:LogonServer
            }
            "MDI" {
                Invoke-MDITriggers
            }
            "Verify" {
                Invoke-VerifyConfiguration
            }
            "BGA" {
                Set-BreakGlassAccount
            }
            "Q" {
                #Get-BestUPNSuffix
                Write-Log -Message "Skipped AS2Go Lab Setup!"
                $repeat = $Script:No
            }

        }
    } Until ($repeat -eq $Script:No)

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    Invoke-Output -T Header -M "Any feedback is welcome - zimmermann.holger@live.de!"

    Write-Log -Message "  >> Force garbage collection"
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    Write-Log -Message "."
    Write-Log -Message "."
    Write-Log -Message "##################################################################"
    Write-Log -Message "#                                                                #"
    Write-Log -Message "#     Ending Module $ASModuleName / $CurrentFunction [Version $($ASModuleManifest.Version)] "
    Write-Log -Message "#                                                                #"
    Write-Log -Message "##################################################################"
    Write-Log -Message "."
    Write-Log -Message "."
}