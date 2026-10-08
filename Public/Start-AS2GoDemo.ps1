
<#
.SYNOPSIS
Starts the AS2Go demo workflow.

.DESCRIPTION
Runs the Attack Scenario To Go (AS2Go) demo sequence and optionally skips
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
Use Get-Help Start-AS2GoDemo -Full to view this help content.
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

    
    Clear-ExfiltrationFolder


    Invoke-Output -T Header -M "Attack Scenario to GO - along the kill-chain (AS2Go)"
    
    $MoAD = Confirm-PoSHModuleAvailabliy -PSModule "ActiveDirectory"
    $MoGPO = Confirm-PoSHModuleAvailabliy -PSModule "GroupPolicy"

    # check the correct directory and requirements

    $Script:ASTools = Get-ASConfig -Setting "Tools"

    $FileVersionM = Get-FileVersion -fullname "$($Script:ASTools)\mimikatz.exe"
    $FileVersionP = Get-FileVersion -fullname "$($Script:ASTools)\PsExec.exe"
    $FileVersionR = Get-FileVersion -fullname "$($Script:ASTools)\Rubeus.exe"
    $FileVersionN = Get-FileVersion -fullname "$($Script:ASTools)\NetSess.exe"
    $FileVersionC = Get-FileVersion -fullname "$($Script:ASTools)\Certify.exe"
    #$FileVersionO = Get-FileVersion -fullname "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

    if ($MoGPO -eq "failed" -or $MoAD -eq "failed" -or $FileVersionM -eq "failed" -or $FileVersionP -eq "failed" -or $FileVersionR -eq "failed" -or $FileVersionN -eq "failed" -or $FileVersionC -eq "failed" -or $FileVersionO -eq "failed") {
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
            Invoke-Phase04BruteForceAttack -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo -Simulation:$Simulation
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
        $MyInfo = "          In this demo, I use the following three user accounts        "
        $MyFGC = $Script:FGCHighLight
    }
    else {
        $MyInfo = "          Still using these three (3) user accounts                    "
        $MyFGC = "Darkblue"

    }

    Update-WindowTitle -NewTitle "Used Accounts"

    Invoke-Output -T Header -M $MyInfo

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



    # only for PosH Script testing hozi MyDebugHelp
    If ($DeveloperMode) {
        # function to test 
        #Restart-VictimMachines
        Write-host "START Run directy" -ForegroundColor Red


        #Restart-VictimMachines

       
        #write-host $mydebug

        #Invoke-Command -ScriptBlock {.\certify.exe find /vulnerable}
        Write-host "END Run directy" -ForegroundColor Red
        Write-Log -Message "Running dedicated function from Developer Mode section"
        pause

    }


    #endregion Attack Phase -  Brute Force Account 

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - COMPROMISED User Account              #####
    ######                                                                     #####
    ################################################################################

    #region Attack Phase - COMPROMISED User Account

    Update-WindowTitle -NewTitle $Script:Phase05
    #Set-ASConfig -Setting "LastStage" -Value $Script:Phase06
    If (-not $SkipImages) { Show-Phases -Phase "phase_000.html" }

    Do {

        If ($SkipCompromisedAccount) { break }    
  

        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -T Header -M "Attack Phase - COMPROMISED User Account"

        If ($UnAttended) {
            $answer = $Script:PrivledgeAccount
        }
        else {



            $title = "Was the compromised account a privileged account?"
            $message = "Target scope:"
            
            $Options = @(
                [pscustomobject] @{ 
                    Label = "&Yes"
                    Help  = 'the account had administrative or elevated privileges'
                    Value = $Script:Yes 
                },
                [pscustomobject] @{ 
                    Label = "&No"
                    Help  = 'the account was a standard user account'
                    Value = $Script:No 
                }
            )
            
            $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 1 -Title $title

        }


        If ($answer -eq $Script:Yes) {
            Write-Log -Message "Starting with a PRIVLEDGE(!) COMPROMISED User Account"
            $UserPic = "phase_008.html"
            $Account = "PRIVLEDGE(!) Compromised "
            $Script:PrivledgeAccount = $Script:Yes
            $PrivilegeEscalation = $Script:PtT
            $reconnaissance = $Script:Yes
            Set-NewColorSchema -NewStage $Script:PtH
            #Color Schema for the next command
            #$fgcS = "Black" # Switch
            #$fgcC = "Darkblue"   # Command
            #$fgcF = "Black"
            #$fgcV = "DarkMagenta" # Value
            #$fgcH = "Darkblue" 
        }
        else {
   
            Write-Log -Message "Starting with a non-sensitive COMPROMISED User Account"
            $UserPic = "phase_005.html"
            $Account = "non-sensitive Compromised"
            $Script:PrivledgeAccount = $Script:No
            $PrivilegeEscalation = $Script:PtH
            $reconnaissance = $Script:No
            Set-NewColorSchema -NewStage $Script:InitialStart
        }

        #Pause
        If (-not $SkipImages) { Show-Phases -Phase $UserPic }
        Get-SessionsOnDC -server $Script:ASDC

        If (-not $SkipClearHost) { Clear-Host }
        Write-Host "____________________________________________________________________`n" 
        Write-Host "        Starting with $Account User Account        "
        Write-Host "____________________________________________________________________`n" 

        $currentUser = $Global:ASVictim
        $currentUser = $env:UserName

        Write-Host -NoNewline "  Command: "
        Write-Highlight -Text ("Get-ADUser ", "-Identity ", "$currentUser") -Color $fgcC, $fgcS, $fgcV

        If ($UnAttended) {
            If ($UseRUBEUS) { $answer = $Script:Yes }else { $answer = $Script:No }
        }
        else {
            $question = "Would you like to run this step - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $Script:Yes
        }

        If ($answer -eq $Script:Yes) {
            Write-Host "`n`n"
            $error.Clear()
            Try {
                $attributes = @("AccountExpirationDate", "CannotChangePassword", "CanonicalName", "cn", "Created", "Department", "Description", "DisplayName", "EmployeeNumber", "Enabled", "Country", "l", "Manager", "MemberOf", "MobilePhone", "userAccountControl", "UserPrincipalName", "LastBadPasswordAttempt", "title")
                get-aduser -Identity $currentUser -Properties $attributes | Format-List | Out-String -ErrorAction Stop
  
            }
            catch {
                $message = $_
                Write-Host " "$message.CategoryInfo.Reason:" " -NoNewline
                $message.Exception
  
                Write-Host ""
                Write-host "  Account restrictions are preventing this user from signing in." -ForegroundColor $fgcH
                Write-HosT "  Probably helpdesk user '$Global:ASHelpDeskUser' is member of the 'Protected Users' Group!`n`n" -ForegroundColor $fgcH
                pause
                #Stop-AS2GoDemo
            }
    


    
            Write-Host ""
            Pause
            If (-not $SkipClearHost) { Clear-Host }
            Write-Host "____________________________________________________________________`n" 
            Write-Host "        Displays a list of currently cached Kerberos tickets        "
            Write-Host "____________________________________________________________________`n" 
            Write-Host ""             
            Write-Host -NoNewline "  Command: "
            Write-Highlight -Text ('klist') -Color $fgcC
            Write-Host ""           
            If ($UnAttended) { Start-Sleep 1 } else { Pause }
            Write-Host ""
            klist
            If ($UnAttended) { Start-Sleep 1 } else { Pause }
            #If (-not $SkipClearHost) { Clear-Host }
        }
        elseIf ($answer -eq $Script:Exit) {
            Stop-AS2GoDemo
        }
        else {
        }

        # If ($skipstep) {break}

        #Invoke-Output -T Header -M "??? REPEAT | Attack Phase - COMPROMISED User Account ???"


        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
            $title = "REPEAT | Attack Phase - $($Script:Phase05)"
            $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }
   
    } Until ($repeat -eq $Script:No)



    #endregion Attack Phase - COMPROMISED User Account

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - RECONNAISSANCE                        #####
    ######                                                                     #####
    ################################################################################

    If ($SkipReconnaissance) {
        Write-Log -Message "Skipped Attack Phase - $($Script:Phase06)"
    }
    else {
        Invoke-Phase06Reconnaissance -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo
    }

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - Privilege Escalation                  #####
    ######                                                                     #####
    ################################################################################

    #https://www.beyondtrust.com/blog/entry/privilege-escalation-attack-defense-explained
    #https://www.microsoft.com/en-us/security/blog/2019/05/09/detecting-credential-theft-through-memory-access-modelling-with-microsoft-defender-atp/


    If ($SkipPrivilegeEscalation) {
        Write-Log -Message "Skipped Attack Phase - $($Script:Phase07)"
    }
    else {
        Invoke-Phase07PrivilegeEscalation -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo
    }


    ################################################################################
    ######                                                                     #####
    ######      Attack Phase - RECONNAISSANCE  with privileged user            #####
    ######                                                                     #####
    ################################################################################


    If ($SkipReconnaissance) {
        Write-Log -Message "Skipped Attack Phase - $($Script:Phase09)"
    }
    else {
        Invoke-Phase09ReconnaissancePriviledged -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo
    }


    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - ACCESS SENSITIVE DATA                 #####
    ######                                                                     #####
    ################################################################################


    If ($SkipSensitiveDataAccess) {
        Write-Log -Message "Skipped Attack Phase - ACCESS SENSITIVE DATA "
    }
    else {
        Invoke-Phase10AccessSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo
        Invoke-Phase11ExfiltrateSensitiveData -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo
    }

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - DOMAIN COMPROMISED AND PERSISTENCE    #####
    ######                                                                     #####
    ################################################################################

    #region Attack Phase -  DOMAIN COMPROMISED AND PERSISTENCE
    If ($SkipDomainPersistence) {
        Write-Log -Message "Skipped Attack Phase - DOMAIN COMPROMISED AND PERSISTENCE"
    }
    else {
        Invoke-Phase12DomainCompromisePersistence -EnableLogging:$EnableLogging -SkipImages:$SkipImages -SkipClearHost:$SkipClearHost -UnAttended:$UnAttended -AS2GODemo
    }
    #endregion Attack Phase -  DOMAIN COMPROMISED AND PERSISTENCE

    ################################################################################
    ######                                                                     #####
    ######                         CLEAN UP                                    #####
    ######                                                                     #####
    ################################################################################

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
