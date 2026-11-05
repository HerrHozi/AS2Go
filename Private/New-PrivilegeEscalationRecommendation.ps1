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
        $Script:ASSAW = Get-ASConfig -Setting "mySAW" -ErrorAction SilentlyContinue
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





    <#
    Write-Host "Does the user have access to \\$Script:ASSAW\c$\temp? $bAdminPC"      
    Write-Host "Is Victim PC $env:COMPUTERNAME member of privileged group? $bMemberofDA"
    Write-Host "Is Help Desk User $Global:ASHelpDeskUser member of Protected Users Group? $bHDMemberofPUG"
    Write-Host "Found at least one risky CA Template? $RiskyCAtemplate"
    Write-Host "Is HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest\UseLogonCredential = 1? $bUseLogonCredential"
    Write-Host "Does $Global:ASHelpDeskUser owns a process? $hdUser"
    Write-Host "Does $Global:ASDomainAdmin owns a process? $daUser"
    Write-Host "Client for currently cached Kerberos tickets? $client"

#>


    #If (-not $SkipClearHost) { Clear-Host }
    Clear-Host
    Write-AS2GoOutput -Type  Header -M "Choose your Type of Privilege Escalation"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    write-host ""
    
    Write-AS2GoOutput -Type Header -Message "Local (Victim) Computer Information"
    $localComputerInformation | Format-List | out-host

    Write-AS2GoOutput -Type Header -Message "Attack Compatibility Matrix"
    $space = "  "
    Write-Host "$space           ║        Win 10       |        Win11 "
    Write-Host "$space           ║  $le $workingWinVersion  |  $ge $LimitedWinVersion  |   21H2   | $ge 22H2 "
    Write-Host "$space  ═════════╬══════════════════════════════════════════"
    Write-Host "$space   PtH     ║    OK    |    OK*   |    OK*   |    --    Pass-the-Hash Attack"  -ForegroundColor Yellow
    Write-Host "$space   PtT     ║    OK    |    OK    |    OK    |    OK    Pass-the-Ticket Attack"  -ForegroundColor Gray
    Write-Host "$space   PtC     ║    --    |    OK    |    OK    |    OK    Abuse misconfigured Certificate Template "  -ForegroundColor Yellow
    Write-Host "$space   WDigest ║    OK    |    OK    |    OK    |    --    Credential Theft through Memory Access"  -ForegroundColor Gray
    Write-Host "$space   SPN     ║    OK    |    OK    |    OK    |    OK    Kerberoasting Attack"  -ForegroundColor Yellow
    Write-Host "" 
    Write-Host "   * CIFS on remote Admin PC works, but LDAP authentication will fail."
    Write-Host "     Pass-the-Ticket attack is therefore possible!" -ForegroundColor Yellow





Write-AS2GoOutput -Type Info -Message "Attack Compatibility Matrix (updated)"

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
Write-Host "   * Pass-the-Hash remains possible if an NTLM hash is obtained from another" -ForegroundColor Yellow
Write-Host "     source and the target service still accepts NTLM authentication." -ForegroundColor Yellow
Write-Host ""
Write-Host "   PtC requires a vulnerable or misconfigured Active Directory Certificate" -ForegroundColor Yellow
Write-Host "     Services (AD CS) certificate template; the client OS itself supports it." -ForegroundColor Yellow
Write-Host ""
Write-Host "   WDigest assumes:" -ForegroundColor Yellow
Write-Host "     HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest\UseLogonCredential = 1" -ForegroundColor Yellow





    Write-AS2GoOutput -Type Header -Message "CURRENT SITUATION FROM AN ATTACKER'S PERSPECTIVE"
    
    $Global:ASVictim = whoami 

    Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
    Write-Host "Compromised User " -NoNewline
    Write-Host "$Global:ASVictim " -NoNewline -ForegroundColor Yellow
    Write-Host "is member of the " -NoNewline
    Write-host "Local Admins!" -ForegroundColor Yellow

    If ($bMemberofDA) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Victim PC " -NoNewline
        Write-Host "$env:COMPUTERNAME " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-host "Domain Admins!" -ForegroundColor Yellow
    }


    If ($bMemberofAO) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Victim PC " -NoNewline
        Write-Host "$env:COMPUTERNAME " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-host "Account Operators!" -ForegroundColor Yellow
    }

    If ($client.ToUpper().contains("VI-")) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "User for currently cached Kerberos tickets is " -NoNewline
        Write-Host "$($client.ToUpper())" -ForegroundColor Yellow
    }
    elseif ($client.ToUpper().contains("(0)")) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "Currently NO cached Kerberos tickets available " -NoNewline
        Write-Host "$($client.ToUpper())" -ForegroundColor Yellow
    }
    else {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Client for currently cached Kerberos tickets is " -NoNewline
        Write-Host "$($client.ToUpper())" -ForegroundColor Yellow
    }
    
    If ($bAdminPC) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Compromised user has access to Admin PC " -NoNewline
        Write-Host "\\$Script:ASSAW\c$!" -ForegroundColor Yellow
    }
    else {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "Your user does NOT have access to share " -NoNewline
        Write-Host "\\$Script:ASSAW\c$!" -ForegroundColor Yellow
    }

    [bool]$condition1 = $false

    If ($value -eq 1) {
        [bool]$condition1 = $true
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-host "UseLogonCredential value is set to " -NoNewline; Write-Host $value -ForegroundColor Yellow -NoNewline
        Write-Host ". WDigest will store credentials in memory!"
    }
    elseif ($value -eq 0) {
        Write-Host "      OK: " -NoNewline -ForegroundColor Yellow
        Write-host "UseLogonCredential value is set to " -NoNewline; Write-Host $value -ForegroundColor Yellow -NoNewline
        Write-Host ". WDigest will NOT store credentials in memory!"
    }
    elseif ($value -eq -1) {
        Write-Host "      OK: " -NoNewline -ForegroundColor Yellow
        Write-Host "UseLogonCredential registry item does not exist."
    }
    else {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "On this on this OS Build CREDENTIAL CACHING in the Windows authentication protocol WDigest is NOT supported."
    }


    If ($bHDMemberofPUG) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-host "HD User " -NoNewline
        Write-host "$Global:ASHelpDeskUser " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
    }
    else {
        If ($Global:ASHelpDeskUser) {
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-host "HD User " -NoNewline
            Write-host "$Global:ASHelpDeskUser " -NoNewline -ForegroundColor Yellow
            Write-Host "is NOT member of the " -NoNewline
            Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
        }

        If ($hdUser -and $condition1) {
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-Host "Credential theft through memory access for user " -NoNewline
            Write-Host "$Global:ASHelpDeskUser " -NoNewline -ForegroundColor Yellow
            Write-Host "is possible!"
        }
    }


    If ($bDAMemberofPUG) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-host "DA User " -NoNewline
        Write-host "$Global:ASDomainAdmin " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
    }
    else {
        If ($Global:ASDomainAdmin) {
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-host "DA User " -NoNewline
            Write-host "$Global:ASDomainAdmin " -NoNewline -ForegroundColor Yellow
            Write-Host "is NOT member of the " -NoNewline
            Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
        }
   
        If ($daUser -and $condition1) {
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-Host "Credential theft through memory access for user " -NoNewline
            Write-Host "$Global:ASDomainAdmin " -NoNewline -ForegroundColor Yellow
            Write-Host "is possible!"
        }
    }

    If ($RiskyCAtemplate) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Found at least one risky CA Template, e.g. " -NoNewline
        Write-Host "$RiskyCAtemplate!" -ForegroundColor Yellow
    }

    If ($OSBuild -le 17134) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "PtC is NOT supported on this machine!"
    }
    
    If ($OSBuild -ge 22621) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "PtH is NOT supported on this machine!"
    }

    If ($AdminWithSPN) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Found at least one Tier 0 account with an " -NoNewline
        Write-Host "Service Principal Name (SPN)!" -ForegroundColor Yellow
    }
    


    #    If ($overview.ToUpper().Contains("WINDOWS 11"))
    #    {
    #        Write-Host "     PtH - is NOT supported on this machine!" -ForegroundColor Red
    #        Write-Host "     PtT - is NOT supported on this machine!" -ForegroundColor Red
    #        Write-Host "     WDigest - is NOT supported on this machine!" -ForegroundColor Red
    #    }





    <#
    [string]$result = $client.Trim().ToUpper()
   
    
    if ($result.StartsWith("DA-")) {

        $recommandtion = "You are already Domain Admin - nothing to do :-)"
    }
    elseif ($result.StartsWith("$env:COMPUTERNAME$".ToUpper())) {

        $recommandtion = "You are nt authority\system - nothing to do :-)"
    }
    elseif ($result.StartsWith("HD-")) {
        Write-Host "Helpdesk User"
        if ($OSBuild -le 17134) {
            Write-Host "until win 10 - 1803"
            #until win 10 - 1803
        }
        elseif (($OSBuild -ge 17763) -and ($OSBuild -lt 22000) ) {
            #<= win 10 - 22H2
            Write-Host "until win 10 - 22H2"
        }
        elseif ($OSBuild -eq 22000) {
            #win 11 - 21H2"
            Write-Host "win 11 - 21H2"
        
        }
        elseif ($OSBuild -ge 22621 ) {
            #starting with win 11 - 22H2"
            Write-Host ">= win 22H2"
        }
        else {
            Write-Host "no match"
        }
    }
    elseif ($result.StartsWith("VI-")) {
        Write-Host "Victim"
        if ($OSBuild -le 17134) {
            #until win 10 - 1803
            Write-Host "until win 10 - 1803"
        }
        elseif (($OSBuild -ge 17763) -and ($OSBuild -lt 22000) ) {
            #<= win 10 - 22H2
            Write-Host "until win 10 - 22H2"
        }
        elseif ($OSBuild -eq 22000) {
            #win 11 - 21H2"
            Write-Host "win 11 - 21H2"
        
        }
        elseif ($OSBuild -ge 22621 ) {
            #starting with win 11 - 22H2"
            Write-Host ">= win 22H2"
        }
        else {
            Write-Host "no match"
        }
    }
    
    else {
        Write-Host "no match"
    }
    



    Write-Host ""
    $recommandtion = "     Steal or Forge Authentication Certificates Attack"
    Write-Host "     RECOMMENDED ATTACK: "
    Write-Host $recommandtion -ForegroundColor Yellow
#>


    Write-Host ""

    
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