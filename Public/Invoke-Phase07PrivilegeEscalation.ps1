<#
.SYNOPSIS
Runs Phase 07 of the AS2Go attack simulation: Privilege Escalation.

.DESCRIPTION
Invoke-ASPhase07PrivilegeEscalation executes the privilege escalation phase in the AS2Go workflow.
It initializes phase context, optionally shows visuals, and presents an attack selection menu that
can be run interactively or in unattended mode using an automatic recommendation.

Depending on the selected option, the phase can trigger attacks and actions such as:
- Pass-the-Hash (PtH) (coming soon)
- Pass-the-Ticket (PtT) (coming soon)
- Kerberoasting
- Misconfigured Certificate Template attack (ESC1)
- Credential theft through memory access (coming soon)
- Enabling memory access settings
- Privilege escalation to SYSTEM (for example via PsExec workflow) (coming soon)

.PARAMETER UnAttended
Runs the phase without interactive confirmation prompts.

.PARAMETER Continue
Reserved switch for workflow continuation handling.

.PARAMETER EnableLogging
Enables extended logging for this phase execution.

.PARAMETER SkipImages
Skips visual phase assets (for example, phase HTML images/pages).

.PARAMETER SkipClearHost
Prevents clearing the console during phase execution.

.PARAMETER AS2GoDemo
Runs the phase in AS2Go demo mode and skips selected setup interactions.

.EXAMPLE
Invoke-ASPhase07PrivilegeEscalation

Runs Phase 07 interactively and lets you choose an escalation technique.

.EXAMPLE
Invoke-ASPhase07PrivilegeEscalation -UnAttended -EnableLogging

Runs Phase 07 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase07PrivilegeEscalation -SkipImages -SkipClearHost

Runs Phase 07 without phase visuals and without clearing the host.

.NOTES
Alias: P07, ESC
Part of: AS2Go attack phase orchestration
#>
function Invoke-Phase07PrivilegeEscalation {

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - Privilege Escalation                  #####
    ######                                                                     #####
    ################################################################################

    #https://www.beyondtrust.com/blog/entry/privilege-escalation-attack-defense-explained
    #https://www.microsoft.com/en-us/security/blog/2019/05/09/detecting-credential-theft-through-memory-access-modelling-with-microsoft-defender-atp/
    [Alias("P07", "ESC")]
    Param (  
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If (-not $AS2GoDemo) { 
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
        $Script:BestDCs = Set-BestDomainController
    }
        
    If (-not $SkipClearHost) { Clear-Host }
        
    Update-WindowTitle -NewTitle $Script:Phase07
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase07
    If (-not $SkipImages) { Show-Phases -Phase "phase_007.html" }
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-Output -T Header -M "Attack Phase - $($Script:Phase07.toupper())"
    Invoke-Output -T Bullet "Reuse captured NTLM hashes to authenticate via Pass-the-Hash"
    Invoke-Output -T Bullet "Reuse stolen Kerberos tickets to authenticate via Pass-the-Ticket"
    Invoke-Output -T Bullet "Roast Kerberos service tickets to recover weak (service) account passwords"
    Invoke-Output -T Bullet "Abuse an ESC1-vulnerable certificate template to impersonate privileged users"
    Invoke-Output -T Bullet "Gain remote code execution as Local System using PsExec"
    Invoke-Output -T Bullet "Extract credentials from process memory"


    Do {
        # If ($skipstep) { break }     

        Set-NewColorSchema -NewStage $Script:InitialStart
        $PrivilegeEscalation = New-PrivilegeEscalationRecommendation -computer $env:COMPUTERNAME

        Invoke-Output -Type Header -Message "Privilege Escalation - Select an Attack Technique"

        Write-Host "  H " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Pass-the-Hash Attack" -NoNewline; Write-Host " ** Coming Soon **" -ForegroundColor Yellow
        Write-Host "  T " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Pass-the-Ticket Attack" -NoNewline; Write-Host " ** Coming Soon **" -ForegroundColor Yellow
        Write-Host "  K " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Kerberoasting Attack"
        Write-Host "  1 " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Misconfigured Certificate Template Attack (ESC1)"
        Write-Host "  X " -ForegroundColor Yellow -NoNewline; Write-Host "- for a PsExec Attack running as Local System (NT AUTHORITY\SYSTEM)"
        Write-Host "  M " -ForegroundColor Yellow -NoNewline; Write-Host "- for Credential Theft via Memory Access" -NoNewline; Write-Host " ** Coming Soon **" -ForegroundColor Yellow
        Write-Host "  E " -ForegroundColor Yellow -NoNewline; Write-Host "- to enable the Memory Access" -NoNewline; Write-Host " ** Coming Soon **" -ForegroundColor Yellow

        Write-host "`n  S " -ForegroundColor Yellow -NoNewline; Write-Host "- to skip this step"

        If ($UnAttended) {
            $answer = $PrivilegeEscalation
        }
        else {
        
            $title = "Privilege Escalation"
            $message = "Select the attack technique to execute."
            $Options = @(
                [pscustomobject] @{
                    Label = "&Kerberoasting"
                    Help  = "Run a Kerberoasting attack to request and crack service account TGS tickets."
                    Value = "Kerberoasting"
                },
                [pscustomobject] @{
                    Label = "ESC&1"
                    Help  = "Abuse Misconfigured Certificate Template Attack (ESC1)."
                    Value = "C"
                },
                [pscustomobject] @{
                    Label = "PSE&xec"
                    Help  = "Abuse PsExec Attack running as Local System (NT AUTHORITY\SYSTEM)."
                    Value = "X"
                },
                #                [pscustomobject] @{
                #                    Label = "Pt&T"
                #                    Help  = "" #"Abuse Pass-the-Ticket Attack."
                #                    Value = $Script:PtT
                #                },
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = "Skip  Privilege Escalation."
                    Value = "S"
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        }

        If ($answer -eq $Script:PtH) {
            #Starting Pass-the-Hash (PtH) Attack on VictimPC
            If (-not $SkipImages) { Show-Phases -Phase "phase_007_PtH.html" }  
            Invoke-PtHAttack
        }
        elseif ($answer -eq $Script:PtT) {
            If (-not $SkipImages) { Show-Phases -Phase "phase_007_PtT.html" } 
            Invoke-PassTheTicketAttack
        }
        elseif ($answer -eq "C" ) {
            # If (-not $SkipImages) { Show-Phases -Phase phase_007_PtT.html } 
            Invoke-PrivilegeEscalationViaESC1
        }
        elseif ($answer -eq "Kerberoasting") {
            #If (-not $SkipImages) { Show-Phases -Phase phase_007_PtT.html } 
            Invoke-KerberoastingAttack
        }
        elseif ($answer -eq $CfM) {
            #If (-not $SkipImages) { Show-Phases -Phase phase_007_PtT.html } 
            New-CredentialTheftThroughMemoryAccess
        }
        elseif ($answer -eq "E") {
            #If (-not $SkipImages) { Show-Phases -Phase phase_007_PtT.html } 
            Set-UseLogonCredential
        }
        elseif ($answer -eq "X") {
            #   If (-not $SkipImages) { Show-Phases -Phase phase_007_PtT.html } 
            Invoke-PrivilegesEscalationViaLocalSystem
        }
        else {
            Invoke-Output -Type Info -Message "Privilege Escalation was skipped."
        }

        #If (-not $SkipClearHost) { Clear-Host }

        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
            $title = "REPEAT | Phase 07 - Privilege Escalation"
            $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }
   
    } Until ($repeat -eq $Script:No)


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
