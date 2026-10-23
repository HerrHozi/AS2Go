
<#
.SYNOPSIS
Starts the AS2Go demo workflow.

.DESCRIPTION
Runs the Attack Scenario to Go (AS2Go) demo sequence and optionally skips
selected phases or user interactions. Use switches to run unattended,
continue from a previous stage, or bypass specific attack steps.

.PARAMETER UnAttended
Runs the workflow without interactive prompts where possible.

.PARAMETER Continue
Continues from the previously stored stage instead of starting from the beginning.

.PARAMETER EnableLogging
Enables module logging output.

.PARAMETER SkipImages
Skips image display steps.

.PARAMETER SkipClearHost
Prevents screen clearing between major stages.

.PARAMETER SkipPopup
Skips popup messages.

.PARAMETER SkipPasswordSpray
Skips the password spray phase.

.PARAMETER SkipCompromisedAccount
Skips compromised account selection/confirmation.

.PARAMETER SkipPwSpayWithRubeus
Skips password spray execution with Rubeus.

.PARAMETER SkipReconnaissance
Skips the reconnaissance phase.

.PARAMETER SkipPrivilegeEscalation
Skips the privilege escalation phase.

.PARAMETER SkipSensitiveDataAccess
Skips the sensitive data access phase.

.PARAMETER SkipDataExfiltration
Skips the data exfiltration phase.

.PARAMETER SkipDomainPersistence
Skips the domain persistence phase.

.PARAMETER SkipForgeAuthCertificates
Skips the certificate forging phase.

.PARAMETER SkipKerberoastingAttack
Skips the Kerberoasting phase.

.PARAMETER DeveloperMode
Enables developer/demo output for troubleshooting and testing.

.PARAMETER Simulation
Runs in simulation mode.

.EXAMPLE
PS> Start-AS2GoDemo
Starts the demo interactively from the beginning.

.EXAMPLE
PS> Start-AS2GoDemo -Continue -EnableLogging -SkipImages
Continues from the last stage and enables logging while skipping images.

.EXAMPLE
PS> Start-AS2GoDemo -UnAttended -SkipPasswordSpray -SkipReconnaissance
Runs unattended and skips selected phases.

.NOTES
[!] AS2Go - IMPORTANT NOTICE
You are about to simulate real-world attacks in a prepared Active Directory environment.
Real attackers may spend days, weeks, months, or even years achieving what AS2Go demonstrates in minutes.
Same techniques. Same attack paths. Different timelines.
Use AS2Go only in explicitly authorized environments.
#>

Function Start-AS2GoDemo {
    Param (  
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$SkipPopup,
        [switch]$SkipPasswordSpray,
        [switch]$SkipCompromisedAccount,
        [switch]$SkipPwSpayWithRubeus,
        [switch]$SkipReconnaissance,
        [switch]$SkipPrivilegeEscalation,
        [switch]$SkipSensitiveDataAccess,
        [switch]$SkipDataExfiltration,
        [switch]$SkipDomainPersistence,
        [switch]$SkipForgeAuthCertificates, 
        [switch]$SkipKerberoastingAttack,
        [switch]$DeveloperMode,
        [switch]$Simulation
    )


    #[bool]$showStep = $true # show the steps in an image
    #[bool]$skipstep = $false # show the steps in an image
    
    $SkipPopup = $true
    Write-Log -Message "."
    Write-Log -Message "."
    Write-Log -Message "<< -- UniversalTime [UTC]"
    Write-Log -Message " "
    Write-Log -Message "##################################################################"
    Write-Log -Message "#                                                                #"
    Write-Log -Message "     Starting Module $ASModuleName [Version $($ASModuleManifest.Version)] "
    Write-Log -Message "#                                                                #"
    Write-Log -Message "##################################################################"
    Write-Log -Message " "
    Write-Log -Message "    >> Using PowerShell version $($PSVersionTable.PSVersion.tostring())"
    Write-Log -Message " "
    Write-Log -Message "Victim PC run on Windows $Script:WinVersion"


    If (-not $SkipClearHost) { Clear-Host }
    $answer = Show-Disclaimer

    if ($answer -eq $Script:No) {
        return
    }   
    
    Clear-ExfiltrationFolder

    Invoke-Output -Type  Header -M "Attack Scenario to Go - along the kill-chain (AS2Go)"
    
    $Script:MoAD = Test-PoSHModuleAvailability -PSModule "ActiveDirectory"
    $Script:MoGPO = Test-PoSHModuleAvailability -PSModule "GroupPolicy"

    # check the correct directory and requirements

    $Script:ASTools = Get-ASConfig -Setting "Tools"

    $FileVersionM = Get-FileVersion -fullname "$($Script:ASTools)\mimikatz.exe"
    $FileVersionP = Get-FileVersion -fullname "$($Script:ASTools)\PsExec.exe"
    $FileVersionR = Get-FileVersion -fullname "$($Script:ASTools)\Rubeus.exe"
    $FileVersionN = Get-FileVersion -fullname "$($Script:ASTools)\NetSess.exe"
    $FileVersionC = Get-FileVersion -fullname "$($Script:ASTools)\Certify.exe"
    #$FileVersionO = Get-FileVersion -fullname "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

    if ($Script:MoGPO -eq $false -or $Script:MoAD -eq $false -or $FileVersionM -eq "failed" -or $FileVersionP -eq "failed" -or $FileVersionR -eq "failed" -or $FileVersionN -eq "failed" -or $FileVersionC -eq "failed" -or $FileVersionO -eq "failed") {
        [bool]$PreCheckFailed = $true
    }

    If ($PreCheckFailed -eq $true) {
        Write-host "`n  [>] Please acknowledge the warning(s) by pressing ENTER ... " -ForegroundColor $Script:FGCWarning -NoNewline
        $confirmed = Read-Host
        Write-Log -Message "        >> Confirmed the warning with - $confirmed"
    }
 
    $demo = Get-ASConfig -Setting "DemoTitle"
    Update-WindowTitle -NewTitle $demo

    # If (-not $SkipClearHost){Clear-Host}
    Set-NewColorSchema -NewStage $Script:PtT

    $laststage = Get-ASConfig -Setting "LastStage"

    If ($UnAttended) {
        if ($Continue) { $Begin = $Script:No } else { $Begin = $Script:Yes }
    }
    else {
        if ($Continue) { $StartValue = $Script:No } else { $StartValue = $Script:Yes }
        $question = "Starts the attack scenario from the beginning? Default "
        $Begin = Get-Answer -question $question -defaultValue $StartValue
    }


    If ($Begin -eq $Script:Yes) {
        Set-ASConfig -Setting "LastStage" -Value $Script:Phase50
        Set-NewColorSchema -NewStage $Script:InitialStart


        If (-not $SkipClearHost) { Clear-Host }
        Write-Host "____________________________________________________________________`n" 
        Write-Host "        $ASModuleName   Version $($ASModuleManifest.Version)             "
        Write-Host "                                                                    "
        Write-Host "        Attack Scenario to Go | along the kill-chain                " -ForegroundColor yellow
        Write-Host "                                                                    "
        Write-Host "        created by Holger Zimmermann | last update $ASModuleLastUpdate      "
        Write-Host "                                                                    "
        Write-Host "        Used tools & requirements:                                  "
        Write-Host "                                                                    "
        Write-Host "        ●  PoSH modules:  ActiveDirectory & GroupPolicy             "
        Write-Host "                                                                    "
        Write-Host "        ●  NetSess.exe    $FileVersionN                             "
        Write-Host "        ●  Mimikatz.exe   $FileVersionM                             "
        Write-Host "                                                                    "
        Write-Host "        ●  Rubeus.exe     $FileVersionR                             "
        Write-Host "        ●  Certify.exe    $FileVersionC                             "
        Write-Host "                                                                    "
        Write-Host "        ●  PsExec.exe     $FileVersionP                             "
        Write-Host "____________________________________________________________________`n" 

        $TimeStamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
        $lastVictim = Get-ASConfig -Setting "LastVictim"
        $lastRun = Get-ASConfig -Setting "LastStart" 
        $lastDuration = Get-ASConfig -Setting "LastDuration" 

        Write-Host "`n  Current Date & Time: $TimeStamp" 
        Write-Host ""
        Write-Host "  Last Run:            " -NoNewline
        Write-Host $lastRun                -NoNewline -ForegroundColor $Script:FGCHighLight
        Write-Host " | "                   -NoNewline
        Write-Host $lastDuration           -NoNewline -ForegroundColor $Script:FGCHighLight
        Write-Host " | Last Victim: "      -NoNewline  
        Write-Host "[$lastVictim]"         -ForegroundColor $Script:FGCHighLight
        Write-Host "`n"
        #Update AS2Go.json config file
        Set-ASConfig -Setting "LastStart" -Value $TimeStamp




        If ($DeveloperMode) {

        }

        If ($UnAttended -eq $false) { pause }

        ################################################################################
        ######                                                                     #####
        ######                Setting update                                       #####
        ######                                                                     #####
        ################################################################################

        If (-not $SkipClearHost) { Clear-Host }
        If ($UnAttended -eq $false) { Get-AS2GoSettings }

        ################################################################################
        ######                                                                     #####
        ######                Attack Phase -  Brute Force Account                  #####
        ######                                                                     #####
        ################################################################################

        If ($SkipPasswordSpray ) {
            Write-Log -Message "Skipped Attack Phase - Brute Force Account"
        }
        else {
            Invoke-ASPhase04BruteForceAttack -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        }

    }
    else {
        $Script:PrivledgeAccount = $Script:Yes
        Set-NewColorSchema -NewStage $Script:PtH
        #read values from AS2Go.json config file
    }

    #read values from AS2Go.json config file
    Get-AS2GoSettings -ReadOnly
    
    $UseCase = Get-ASConfig -Setting "usecase"

    If (-not $SkipClearHost) { Clear-Host }

    If ($Begin -eq $Script:Yes) {
        $MyInfo = "This demo uses the following user & computer principals"
        $MyFGC = $Script:FGCHighLight
    }
    else {
        $MyInfo = "Still using the following user & computer principals"
        $MyFGC = "Darkblue"
    }

    Update-WindowTitle -NewTitle "Used Accounts"

    Invoke-Output -Type  Header -M $MyInfo

    $Global:ASVictim = $env:UserName

    if ($Global:ASVictim -match "^VI-|^HD-|^DA-") {

        $suffix = $Global:ASVictim.Substring(3)

        If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
            $question = " -> Enter or confirm your account suffix! Default "
            $suffix = Get-Answer -question $question -defaultValue $suffix
        }

        $Global:ASVictim = "VI-$suffix"
        $Global:ASHelpDeskUser = "HD-$suffix"
        $Global:ASDomainAdmin = "DA-$suffix"
    }
    else {
        $Global:ASVictim = $env:UserName
    }
    #If (-not $SkipClearHost){Clear-Host}



    Write-Host ""
    Write-Host "  Compromised Account  --  " -NoNewline
    Write-Host                                  $Global:ASVictim -ForegroundColor $fgcC -NoNewline
    Write-Host " | Tier 2 Account"
    
    if ($Global:ASHelpDeskUser) {
        Write-Host "  Helpdesk User        --  $Global:ASHelpDeskUser | Tier 1 Account"
    }
    if ($Global:ASDomainAdmin) {
        Write-Host "  Domain Admin         --  $Global:ASDomainAdmin | Tier 0 Account"
    }

    If ($Begin -eq $Script:Yes) {
               
        $infoV = Get-ComputerInformation -computer $Script:ASVictimMaschine
        $infoS = Get-ComputerInformation -computer $Script:ASSAW
        $infoD = Get-ComputerInformation -computer $Script:ASDC
        
        Write-Host ""
        Write-Host "  Victim Maschine      --  $infoV  | Tier 2 Maschine"
        Write-Host "  Admin Maschine       --  $infoS  | Tier 0 Maschine" 
        Write-Host "  Domain Controller    --  $infoD  | Tier 0 Maschine" 
   
        try {
            Write-Output $Global:ASHelpDeskUser | Set-Clipboard
        }
        catch {
            Write-Output $Global:ASHelpDeskUser | clip
        }
        
        If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
            $wshell = New-Object -ComObject Wscript.Shell
            $Output = $wshell.Popup("Do NOT forget to simulate helpdesk support by ""$Global:ASHelpDeskUser"" on your Victim PC!", 0, "Simulate helpdesk support on Victim PC - hd.cmd", 0 + 64)
        }

    }
    else {
        If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
            $wshell = New-Object -ComObject Wscript.Shell
            $Output = $wshell.Popup("Do NOT forget to simulate domain activities by ""$Global:ASDomainAdmin"" on your Admin PC!", 0, "Simulate domain activities on Admin PC", 0 + 64)           
        }

    }

    Write-Host ""
    Set-ASConfig -Setting "LastVictim" -Value $Global:ASVictim


    If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
        Start-Sleep 2
    }
    else {
        Pause
    }


    #endregion Attack Phase -  Brute Force Account 

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - COMPROMISED User Account              #####
    ######                                                                     #####
    ################################################################################

    #region Attack Phase - COMPROMISED User Account



    Invoke-Output -Type HEADER -Message "ATTACK NAVIGATION"
    Invoke-Output -Type H1 -Message "Choose your starting point in the attack chain.`n"

    Invoke-output -Type Bullet -Message "[4] $Script:Phase04" 
    Invoke-output -Type Bullet -Message "[5] $Script:Phase05"
    Invoke-output -Type Bullet -Message "[6] $Script:Phase06"
    Invoke-output -Type Bullet -Message "[7] $Script:Phase07"
    #Invoke-output -Type Bullet -Message "[8] $Script:Phase08"
    Invoke-output -Type Bullet -Message "[9] $Script:Phase09"   
    Invoke-output -Type Bullet -Message "[1] $Script:Phase10"
    Invoke-output -Type Bullet -Message "[E] $Script:Phase11"
    Invoke-output -Type Bullet -Message "[T] $Script:Phase12"

    Show-CurrentPhase -Phase "phase_00.html"

    $Options = @(
        [pscustomobject]@{
            Label = "&4"
            Help  = "Execute brute force or password spraying attacks to compromise user accounts"
            Value = 4
        },
        [pscustomobject]@{
            Label = "&5"
            Help  = "Establish initial access using a compromised account"
            Value = 5
        },
        [pscustomobject]@{
            Label = "&6"
            Help  = "Perform reconnaissance using a compromised account"
            Value = 6
        },
        [pscustomobject]@{
            Label = "&7"
            Help  = "Execute privilege escalation techniques to gain administrative access"
            Value = 7
        },
        [pscustomobject]@{
            Label = "&9"
            Help  = "Perform reconnaissance using a privileged account"
            Value = 9
        },
        [pscustomobject]@{
            Label = "&1"
            Help  = "Access sensitive data using elevated privileges"
            Value = 10
        },
        [pscustomobject]@{
            Label = "&E"
            Help  = "Exfiltrate sensitive data from compromised systems"
            Value = 11
        },
        [pscustomobject]@{
            Label = "&T"
            Help  = "Execute domain compromise techniques and establish persistence"
            Value = 12
        }
    )
    $title = "Select an attack phase to start or continue your attack scenario."
    $message = ""
    $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 1 -Title $title


    if ($decision -eq 4) {
        Invoke-ASPhase04BruteForceAttack -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase05InitialAccess -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
   
    }
    elseif ($decision -eq 5) {
        Invoke-ASPhase05InitialAccess -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation

    }
    elseif ($decision -eq 6) {
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation

    }
    elseif ($decision -eq 7) {
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation

    }
    elseif ($decision -eq 9) {
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
    }
    elseif ($decision -eq 10) {
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
    }
    elseif ($decision -eq 11) {
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation

    }
    elseif ($decision -eq 12) {
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
    }

    return

 
    Stop-AS2GoDemo


    <# Ideen 


enter-pssession -ComputerName Ch01-DSP-MGMT


try
{
#https://www.hackingarticles.in/credential-dumping-wdigest/

$UseLogonCredential = Get-ItemPropertyValue -Name UseLogonCredential -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
Write-Host $UseLogonCredential
}
catch
{
Write-Host Get-ItemPropertyValue : Property UseLogonCredential does not exist at path -ForegroundColor yellow
}

try
{
$UseLogonCredential = Get-ItemPropertyValue -Name UseLogonCredential -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
}
catch
{
Write-Host Get-ItemPropertyValue : Property UseLogonCredential does not exist at path -ForegroundColor yellow
}

Get-ChildItem ??-*.* | Move-Item -Destination .\Clean-up -Force

#>
}
