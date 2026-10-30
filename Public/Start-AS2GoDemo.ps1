
<#
.SYNOPSIS
Starts the AS2Go demo workflow.

.DESCRIPTION
Runs the Attack Scenario to Go (AS2Go) demo sequence and optionally skips
selected phases or user interactions. Use switches to run unattended,
continue from a previous stage, or bypass specific attack steps.

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

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

.PARAMETER SkipDataExfiltration
Skips the data exfiltration phase.

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
        [switch]$Preview,
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
        [switch]$SkipDataExfiltration,
        [switch]$SkipForgeAuthCertificates, 
        [switch]$SkipKerberoastingAttack,
        [switch]$DeveloperMode,
        [switch]$Simulation,
        [validateSet("PtH", "PtT", "Kerberoasting", "ESC1", "WDigest", "PsExec")]
        [String]$PrivilegeEscalation,
        [validateSet("Encrypt", "Reboot", "BackdoorUser", "GPT", "UserManipulation", "GroupManipulation")]
        [String]$DomainPersistence
    )
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Start-AS2GoDemo' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }



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
    
    $result = Get-ASConfig -Setting "LastConfig"
    If ($null -eq $result) {
    Write-AS2GoOutput -Type Warning -M "No previous configuration found. Run 'Initialize-AS2GoLabConfiguration' first."
        return
    }
    
    Clear-ExfiltrationFolder

    Write-AS2GoOutput -Type  Header -M "Attack Scenario to Go - along the kill-chain (AS2Go)"
    
    $Script:MoAD = Test-PoSHModuleAvailability -PSModule "ActiveDirectory"
    $Script:MoGPO = Test-PoSHModuleAvailability -PSModule "GroupPolicy"

    # check the correct directory and requirements

    $Script:ASTools = Get-ASConfig -Setting "Tools"

    $Script:FileVersionM = Get-FileVersion -fullname "$($Script:ASTools)\mimikatz.exe"
    $Script:FileVersionP = Get-FileVersion -fullname "$($Script:ASTools)\PsExec.exe"
    $Script:FileVersionR = Get-FileVersion -fullname "$($Script:ASTools)\Rubeus.exe"
    $Script:FileVersionN = Get-FileVersion -fullname "$($Script:ASTools)\NetSess.exe"
    $Script:FileVersionC = Get-FileVersion -fullname "$($Script:ASTools)\Certify.exe"


    if (-not $Script:MoGPO -or -not $Script:MoAD -or -not $Script:FileVersionM -or -not $Script:FileVersionP -or -not $Script:FileVersionR -or -not $Script:FileVersionN -or -not $Script:FileVersionC) {
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
    $null = Get-AS2GoSettings -ReadOnly
    
    $UseCase = Get-ASConfig -Setting "usecase"


                    Show-ForestOverview 
                Get-ForestInfo

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

    Write-AS2GoOutput -Type  Header -M $MyInfo

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



    Write-AS2GoOutput -Type HEADER -Message "ATTACK NAVIGATION"
    Write-AS2GoOutput -Type H1 -Message "Choose your starting point in the attack chain.`n"

    Write-AS2GoOutput -Type Bullet -Message "[P] $Script:Phase04" 
    Write-AS2GoOutput -Type Bullet -Message "[I] $Script:Phase05"
    Write-AS2GoOutput -Type Bullet -Message "[R] $Script:Phase06"
    Write-AS2GoOutput -Type Bullet -Message "[E] $Script:Phase07"
    #Write-AS2GoOutput -Type Bullet -Message "[8] $Script:Phase08"
    Write-AS2GoOutput -Type Bullet -Message "[V] $Script:Phase09"   
    Write-AS2GoOutput -Type Bullet -Message "[S] $Script:Phase10"
    Write-AS2GoOutput -Type Bullet -Message "[X] $Script:Phase11"
    Write-AS2GoOutput -Type Bullet -Message "[D] $Script:Phase12"

    Show-CurrentPhase -Phase "phase_00.html"

    $Options = @(
        [pscustomobject]@{
            Label = "S&pray"
            Help  = "Execute brute force or password spraying attacks to compromise user accounts"
            Value = 4
        },
        [pscustomobject]@{
            Label = "&Initial"
            Help  = "Establish initial access using a compromised account"
            Value = 5
        },
        [pscustomobject]@{
            Label = "&Recon"
            Help  = "Perform reconnaissance using a compromised account"
            Value = 6
        },
        [pscustomobject]@{
            Label = "&Escalate"
            Help  = "Execute privilege escalation techniques to gain administrative access"
            Value = 7
        },
        [pscustomobject]@{
            Label = "&Privileged"
            Help  = "Perform reconnaissance using a privileged account"
            Value = 9
        },
        [pscustomobject]@{
            Label = "&Sensitive"
            Help  = "Access sensitive data using elevated privileges"
            Value = 10
        },
        [pscustomobject]@{
            Label = "E&xfil"
            Help  = "Exfiltrate sensitive data from compromised systems"
            Value = 11
        },
        [pscustomobject]@{
            Label = "&Domain"
            Help  = "Execute domain compromise techniques and establish persistence"
            Value = 12
        }
    )
    $title = "Select an attack phase to start or continue your attack scenario."
    $message = ""
    $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 1 -Title $title


    $privilegeEscalationParameters = @{}
    if (-not [string]::IsNullOrEmpty($PrivilegeEscalation)) {
        $privilegeEscalationParameters.PrivilegeEscalation = $PrivilegeEscalation
    }

    $domainPersistenceParameters = @{}
    if (-not [string]::IsNullOrEmpty($DomainPersistence)) {
        $domainPersistenceParameters.DomainPersistence = $DomainPersistence
    }

    if ($decision -eq 4) {
        Invoke-ASPhase04BruteForceAttack -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase05InitialAccess -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters
   
    }
    elseif ($decision -eq 5) {
        Invoke-ASPhase05InitialAccess -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters

    }
    elseif ($decision -eq 6) {
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters

    }
    elseif ($decision -eq 7) {
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters

    }
    elseif ($decision -eq 9) {
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters
    }
    elseif ($decision -eq 10) {
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters
    }
    elseif ($decision -eq 11) {
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters

    }
    elseif ($decision -eq 12) {
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation @domainPersistenceParameters
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
