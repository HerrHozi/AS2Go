<#
.SYNOPSIS
Assesses host and Active Directory conditions relevant to privilege escalation.

.DESCRIPTION
Collects OS details, cached Kerberos tickets, group membership, admin-share access, and WDigest
settings, along with SPN and certificate-template findings. Displays these findings and OS
compatibility for several privilege-escalation techniques.

.PARAMETER computer
Computer name used to collect the target's operating system details.

.OUTPUTS
System.String. Returns the constant value "C".

.FUNCTIONALITY
Displays host compatibility and security conditions relevant to privilege escalation.

.COMPONENT
Category: Sub Function
#>
function New-PrivilegeEscalationRecommendation {

    ################################################################################
    #####                                                                      ##### 
    #####  Find the best priviledge escalation based of the current situation  #####                              
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $computer
    )

    $Info = Measure-FunctionRuntime -Begin

    If ($null -eq $Script:ASSAW) {
        $Script:ASSAW = Get-ASConfig -Setting "AS2GoSAW" -ErrorAction SilentlyContinue
    }

    [bool]$condition1 = $false
    [bool]$condition2 = $true


    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type  Header -M "Choose your Type of Privilege Escalation"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-Host "`n     ... please be patient, while checking your environment ... " -ForegroundColor Yellow


    If ($env:COMPUTERNAME -eq $computer) {
        Write-log -Message "Running on the target computer itself."
        $localComputerInformation = Get-LocalComputerInformation
        $version = $localComputerInformation.Version
        $OSBuild = $localComputerInformation.OSBuild
    }
    else {
        $overview = Get-ComputerInformation -computer $computer
        $temp = $overview.Replace("        ", " ")
        $overview = $temp.Replace("      ", " ")
    
        $version = Get-OSVersion -computer $computer
        [int]$OSBuild = Get-OSBuild -computer $computer
    }


 
 
    #only for testing
    #$OSBuild = 22621

    $le = [char]0x2264
    $ge = [char]0x2265
    $OK = [char]0x263A
    $col = [char]0x2551

    [int]$workingWinVersion = 1803
    [int]$LimitedWinVersion = 1809

    #found

    [bool]$bUseLogonCredential = $false     
    If ($OSBuild -ge 22621) {
        #means not supported
        [int]$value = -2
    }
    else {

        try {
            [int]$value = Get-ItemPropertyValue -Name 'UseLogonCredential' -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest'
            If ($value -eq 1) { $bUseLogonCredential = $true }
        }
        catch {
            #means not ItemPropertyValue not available
            [int]$value = -1
        }
    }


    [bool]$result = Test-Connection -ComputerName $Script:ASSAW -Quiet -Count 1 -ErrorAction SilentlyContinue

    If ($result -eq $true) {
        try {
            [bool]$bAdminPC = Test-Path -Path "\\$Script:ASSAW\c$" -ErrorAction Stop
        }
        catch {
            [bool]$bAdminPC = $false
        }

    }
    else {
        [bool]$bAdminPC = $false
    }



    [bool]$hdUser = Search-ProcessForAS2GoUsers -user  $Global:ASHelpDeskUser
    [bool]$daUser = Search-ProcessForAS2GoUsers -user  $Global:ASDomainAdmin 
    [bool]$bMemberofDA = Search-ADGroupMemberShip -name "$env:COMPUTERNAME$" -rID "-512"
    [bool]$bMemberofAO = Search-ADGroupMemberShip -name "$env:COMPUTERNAME$" -rID "-548"
    [bool]$bHDMemberofPUG = Search-ADGroupMemberShip -name $Global:ASHelpDeskUser -rID "-525"
    [bool]$bDAMemberofPUG = Search-ADGroupMemberShip -name $Global:ASDomainAdmin -rID "-525"
    [bool]$AdminWithSPN = Get-AdminWithSPN
    $RiskyCAtemplate = Get-RiskyEnrolledTemplates -SuppressOutPut

    $client = Get-CachedKerberosTicketsClient

    $lsassStatus = Get-LsassProtectionStatus

    Clear-Host
    Write-AS2GoOutput -Type  Header -M "Choose your Type of Privilege Escalation"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    write-host ""
    
    Write-AS2GoOutput -Type Header -Message "Local (Victim) Computer Information"
    $localComputerInformation | Format-List | out-host

    Write-AS2GoOutput -Type Header -Message "Attack Compatibility Matrix"

    $space = "  "

    Write-Host "$space             ║      Client OS      |           Server OS              "
    Write-Host "$space             ║  Win 10  |  Win 11  |  2019   |  2022   |  2025        "
    Write-Host "$space  ═══════════╬════════════════════════════════════════════════════════"
    Write-Host "$space   PtH       ║   OK*    |   OK*    |   OK*   |   OK*   | Limited*   Pass-the-Hash Attack" -ForegroundColor Yellow
    Write-Host "$space   PtT       ║   OK     | Limited  |   OK    |   OK    | Limited    Pass-the-Ticket Attack" -ForegroundColor Gray
    Write-Host "$space   PtC       ║   OK     |   OK     |   OK    |   OK    |   OK       Abuse misconfigured Certificate Template" -ForegroundColor Yellow
    Write-Host "$space   WDigest   ║   OK     |   OK     |   OK    |   OK    |   OK       Credential Theft through Memory Access" -ForegroundColor Gray
    Write-Host "$space   SPN       ║   OK     |   OK     |   OK    |   OK    | Limited    Kerberoasting Attack" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "   OK       = Technically supported / possible from an OS perspective." -ForegroundColor Gray
    Write-Host "   Limited  = Restricted by default OS hardening, but not fully prevented." -ForegroundColor Gray
    Write-Host ""
    Write-Host "   *Pass-the-Hash remains possible if an NTLM hash is obtained from another" -ForegroundColor Yellow
    Write-Host "     source and the target service still accepts NTLM authentication." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   PtC requires a vulnerable or misconfigured Active Directory Certificate" -ForegroundColor Yellow
    Write-Host "     Services (AD CS) certificate template; the client OS itself supports it." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   WDigest assumes:" -ForegroundColor Yellow
    Write-Host "     HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest\UseLogonCredential = 1" -ForegroundColor Yellow


    Write-AS2GoOutput -Type Header -Message "CURRENT SITUATION FROM AN ATTACKER'S PERSPECTIVE"
    
    $Global:ASVictim = whoami 

    $currentUser = Test-LocalAdministrator

If ($currentUser.IsLocalAdmin) {
    Write-AS2GoOutput -Type TOP -Message "Current user '$Global:ASVictim' has local administrator privileges."
}
else {
    Write-AS2GoOutput -Type BAD -Message "Current user '$Global:ASVictim' does not have local administrator privileges."
}

if ($lsassStatus.IsElevated) {
    Write-AS2GoOutput -Type TOP -Message 'The current PowerShell process is running with an elevated administrator token.'
}
else {
    Write-AS2GoOutput -Type BAD -Message 'The current PowerShell process is not running with an elevated administrator token.'
}

If ($bMemberofDA) {
    Write-AS2GoOutput -Type TOP -Message "Victim PC '$env:COMPUTERNAME' is a member of the" -TextMaker 'Domain Admins group.'
}

If ($bMemberofAO) {
    Write-AS2GoOutput -Type TOP -Message "Victim PC '$env:COMPUTERNAME' is a member of the" -TextMaker 'Account Operators group.'
}

if ($lsassStatus.PplRuntimeConfirmed) {
    Write-AS2GoOutput -Type BAD -Message 'Evidence of LSASS starting as a protected process (PPL) was found for the current boot.'
}
else {
    Write-AS2GoOutput -Type TOP -Message 'No evidence of LSASS starting as a protected process (PPL) was found for the current boot.'
}

if ($lsassStatus.CredentialGuardRunning) {
    Write-AS2GoOutput -Type BAD -Message 'Credential Guard is running.'
}
else {
    Write-AS2GoOutput -Type TOP -Message 'Credential Guard is not running.'
}

if ($lsassStatus.VbsRunning) {
    Write-AS2GoOutput -Type BAD -Message 'Virtualization-Based Security (VBS) is running.'
}
else {
    Write-AS2GoOutput -Type TOP -Message 'Virtualization-Based Security (VBS) is not running.'
}

if ($lsassStatus.DefenderRealTimeProtection) {
    Write-AS2GoOutput -Type BAD -Message 'Microsoft Defender real-time protection is enabled.'
}
else {
    Write-AS2GoOutput -Type TOP -Message 'Microsoft Defender real-time protection is disabled.'
}

if ($lsassStatus.DefenderBehaviorMonitoring) {
    Write-AS2GoOutput -Type BAD -Message 'Microsoft Defender behavior monitoring is enabled.'
}
else {
    Write-AS2GoOutput -Type TOP -Message 'Microsoft Defender behavior monitoring is disabled.'
}

if ($lsassStatus.DefenderEdrRunning) {
    Write-AS2GoOutput -Type BAD -Message 'Microsoft Defender for Endpoint is running.'
}
else {
    Write-AS2GoOutput -Type TOP -Message 'Microsoft Defender for Endpoint is not running.'
}

If ($client.ToUpper().Contains('VI-')) {
    Write-AS2GoOutput -Type BAD -Message 'User for currently cached Kerberos tickets is' -TextMaker "$($client.ToUpper())"
}
elseif ($client.ToUpper().Contains('(0)')) {
    Write-AS2GoOutput -Type BAD -Message 'Currently no cached Kerberos tickets are available for' -TextMaker "$($client.ToUpper())"
}
else {
    Write-AS2GoOutput -Type TOP -Message 'Client for currently cached Kerberos tickets is' -TextMaker "$($client.ToUpper())"
}

If ($bAdminPC) {
    Write-AS2GoOutput -Type TOP -Message 'The compromised user has access to the admin share on' -TextMaker "\\$Script:ASSAW\c$!"
}
else {
    Write-AS2GoOutput -Type BAD -Message 'The current user does not have access to the share' -TextMaker "\\$Script:ASSAW\c$!"
}

[bool]$condition1 = $false

If ($value -eq 1) {
    [bool]$condition1 = $true
    Write-AS2GoOutput -Type TOP -Message 'WDigest will store credentials in memory. The UseLogonCredential registry value is set to' -TextMaker "$value"
}
elseif ($value -eq 0) {
    Write-AS2GoOutput -Type OK -Message 'WDigest will not store credentials in memory. The UseLogonCredential registry value is set to' -TextMaker "$value"
}
elseif ($value -eq -1) {
    Write-AS2GoOutput -Type OK -Message 'The UseLogonCredential registry value does not exist.'
}
else {
    Write-AS2GoOutput -Type BAD -Message 'Credential caching in the Windows authentication protocol WDigest is not supported on this OS build.'
}

If ($bHDMemberofPUG) {
    Write-AS2GoOutput -Type BAD -Message "HD user $Global:ASHelpDeskUser is a member of the Protected Users security group." -TextMaker "$Global:ASHelpDeskUser"
}
else {
    If ($Global:ASHelpDeskUser) {
        Write-AS2GoOutput -Type TOP -Message "HD user $Global:ASHelpDeskUser is not a member of the Protected Users security group." -TextMaker "$Global:ASHelpDeskUser"
    }

    If ($hdUser -and $condition1) {
        Write-AS2GoOutput -Type TOP -Message "Credential theft through memory access is possible for user" -TextMaker "$Global:ASHelpDeskUser"
    }
}

If ($bDAMemberofPUG) {
    Write-AS2GoOutput -Type BAD -Message "DA user $Global:ASDomainAdmin is a member of the Protected Users security group." -TextMaker "$Global:ASDomainAdmin"
}
else {
    If ($Global:ASDomainAdmin) {
        Write-AS2GoOutput -Type TOP -Message "DA user $Global:ASDomainAdmin is not a member of the Protected Users security group." -TextMaker "$Global:ASDomainAdmin"
    }

    If ($daUser -and $condition1) {
        Write-AS2GoOutput -Type TOP -Message 'Credential theft through memory access is possible for user' -TextMaker "$Global:ASDomainAdmin"
    }
}

If ($RiskyCAtemplate) {
    Write-AS2GoOutput -Type TOP -Message 'At least one risky CA template was found, for example:' -TextMaker "$RiskyCAtemplate"
}

If ($OSBuild -le 17134) {
    Write-AS2GoOutput -Type BAD -Message 'PtC is not supported on this machine.'
}

If ($OSBuild -ge 22621) {
    Write-AS2GoOutput -Type BAD -Message 'PtH is not supported on this machine.'
}

If ($AdminWithSPN) {
    Write-AS2GoOutput -Type TOP -Message 'At least one Tier 0 account has a' -TextMaker 'Service Principal Name (SPN).'
}

    
    Write-Log -Message "    >> Your Victim PC settings -  $overview - $version"
    Measure-FunctionRuntime -End -Details $Info

    return "C"

}



function Write-AS2GoAttackMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Matrix
    )

    $rowIndex = 0

    foreach ($line in $Matrix) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            Write-Host ""
            continue
        }

        $color = if ($line -match '^\s*Attack\s*║') {
            'Cyan'
        }
        elseif ($line -match '^\s*═') {
            'DarkGray'
        }
        else {
            if ($rowIndex % 2 -eq 0) {
                'Yellow'
            }
            else {
                'Gray'
            }

            $rowIndex++
        }

        Write-Host $line -ForegroundColor $color
    }
}