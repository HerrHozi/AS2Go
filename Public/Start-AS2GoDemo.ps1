
<#
.SYNOPSIS
Starts the AS2Go demo workflow.

.DESCRIPTION
Runs the AS2Go workflow from the selected attack phase. Use the supported switches
to preview or run unattended, control visual output, or select attack techniques.

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

.PARAMETER DeveloperMode
Enables developer/demo output for troubleshooting and testing.

.EXAMPLE
PS> Start-AS2GoDemo
Starts the demo interactively from the beginning.

.EXAMPLE
PS> Start-AS2GoDemo -Continue -EnableLogging -SkipImages
Continues from the last stage and enables logging while skipping images.

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
        [switch]$DeveloperMode,
        [validateSet("PtH", "PtT", "Kerberoasting", "ESC1", "WDigest", "PsExec")]
        [String]$PrivilegeEscalation,
        [validateSet("Encrypt", "Reboot", "BackdoorUser", "GPT", "UserManipulation", "GroupManipulation")]
        [String]$DomainPersistence,
        [switch]$SafeMode
    )
    
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Start-AS2GoDemo' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

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
    Write-Log -Message "Lab PC run on Windows $Script:WinVersion"


    If (-not $SkipClearHost) { Clear-Host }
   
    $answer = Show-Disclaimer

    if ($answer -eq $Script:No) {
        return
    }
    
    if (-not $safeMode) {
        $result = Get-ASConfig -Setting "LastConfig"
        If ($null -eq $result) {
            Write-AS2GoOutput -Type Warning -M "No previous configuration found. Run 'Initialize-AS2GoLab' first."
            return
        }
    }

    Clear-ExfiltrationFolder

    Write-AS2GoOutput -Type  Header -M "Attack Scenario to Go - along the kill-chain (AS2Go)"
    
    #Show-CurrentPhase -Phase "ASP00.html"

    $Script:MoAD = Test-PoSHModuleAvailability -PSModule "ActiveDirectory"
    $Script:MoGPO = Test-PoSHModuleAvailability -PSModule "GroupPolicy"

    Write-Host ""

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
        $null = Write-AS2GoOutput -Type Input -M "Acknowledging warnings before proceeding..."
        Write-host "`n  [>] Please acknowledge the warning(s) by pressing ENTER ... " -ForegroundColor $Script:FGCWarning -NoNewline
    }
 
    $demo = Get-ASConfig -Setting "DemoTitle"
    Update-WindowTitle -NewTitle $demo

    Set-NewColorSchema -NewStage $Script:PtT

    $laststage = Get-ASConfig -Setting "LastStage"

    $Begin = $Script:No
    If ($Begin -eq $Script:Yes) {
        Set-ASConfig -Setting "LastStage" -Value $Script:Phase50
        Set-NewColorSchema -NewStage $Script:InitialStart

        If (-not $SkipClearHost) { Clear-Host }

        $TimeStamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
        $lastCompromisedAccount = Get-ASConfig -Setting "LastCompromisedAccount"
        $lastRun = Get-ASConfig -Setting "LastStart" 
        $lastDuration = Get-ASConfig -Setting "LastDuration" 

        Write-Host "`n  Current Date & Time: $TimeStamp" 
        Write-Host ""
        Write-Host "  Last Run:            " -NoNewline
        Write-Host $lastRun                -NoNewline -ForegroundColor $Script:FGCHighLight
        Write-Host " | "                   -NoNewline
        Write-Host $lastDuration           -NoNewline -ForegroundColor $Script:FGCHighLight
        Write-Host " | Last Compromised Account: "      -NoNewline
        Write-Host "[$lastCompromisedAccount]"         -ForegroundColor $Script:FGCHighLight
        Write-Host "`n"
        #Update AS2Go.json config file
        Set-ASConfig -Setting "LastStart" -Value $TimeStamp


        If ($UnAttended -eq $false) { pause }

        If (-not $SkipClearHost) { Clear-Host }
        If ($UnAttended -eq $false) { Get-AS2GoSettings }

        ################################################################################
        ######                                                                     #####
        ######                Attack Phase -  Brute Force Account                  #####
        ######                                                                     #####
        ################################################################################





        
        Invoke-ASPhase04BruteForceAttack -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode

    }
    else {
        $Script:PrivledgeAccount = $Script:Yes
        Set-NewColorSchema -NewStage $Script:PtH
        #read values from AS2Go.json config file
    }

    #read values from AS2Go.json config file
    $null = Get-AS2GoSettings -ReadOnly
    
    $UseCase = Get-ASConfig -Setting "usecase"

    If (-not $safeMode) {
        Show-ForestOverview 
        Get-ForestInfo
    
        $infoV = Get-ComputerInformation -computer $Script:ASLabComputer
        $infoS = Get-ComputerInformation -computer $Script:ASSAW
        $infoD = Get-ComputerInformation -computer $Script:ASDC
    
    }




    If (-not $SkipClearHost) { Clear-Host }
    $Global:ASCompromisedAccount = $env:UserName
 

    Write-Host ""
    Set-ASConfig -Setting "LastCompromisedAccount" -Value $Global:ASCompromisedAccount

    If ($UnAttended -ne $true) {
        Start-Sleep 2
    }
    else {
        Pause
    }


    Show-CurrentPhase -Phase "ASP00.html"
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
            Label = "Pri&vileged"
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
   
    If ($unattended) {
        $decision = 4
    }
    else {
        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 1 -Title $title
    }



    $privilegeEscalationParameters = @{}
    if (-not [string]::IsNullOrEmpty($PrivilegeEscalation)) {
        $privilegeEscalationParameters.PrivilegeEscalation = $PrivilegeEscalation
    }

    $domainPersistenceParameters = @{}
    if (-not [string]::IsNullOrEmpty($DomainPersistence)) {
        $domainPersistenceParameters.DomainPersistence = $DomainPersistence
    }

    if ($decision -eq 4) {
        Invoke-ASPhase04BruteForceAttack -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase05InitialAccess -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 5) {
        Invoke-ASPhase05InitialAccess -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 6) {
        Invoke-ASPhase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 7) {
        Invoke-ASPhase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @privilegeEscalationParameters
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 9) {
        Invoke-ASPhase09ReconnaissancePrivileged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 10) {
        Invoke-ASPhase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 11) {
        Invoke-ASPhase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }
    elseif ($decision -eq 12) {
        Invoke-ASPhase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GoDemo -SafeMode:$SafeMode @domainPersistenceParameters
    }

    return
 
    Stop-AS2GoDemo
}
