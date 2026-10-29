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

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

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
function Invoke-ASPhase07PrivilegeEscalation {

    ################################################################################
    ######                                                                     #####
    ######                Attack Phase - Privilege Escalation                  #####
    ######                                                                     #####
    ################################################################################

    #https://www.beyondtrust.com/blog/entry/privilege-escalation-attack-defense-explained
    #https://www.microsoft.com/en-us/security/blog/2019/05/09/detecting-credential-theft-through-memory-access-modelling-with-microsoft-defender-atp/
    [Alias("ASP07", "ESC")]
    Param (  
        [switch]$Preview,
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [validateSet("PtH", "PtT", "Kerberoasting", "ESC1", "WDigest", "PsExec")]
        [String]$PrivilegeEscalation
    )
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase07PrivilegeEscalation' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }


    $info = Measure-FunctionRuntime -Begin
    
    $functionCallParameters = Get-FunctionCallParameters -FunctionName $MyInvocation.MyCommand.Name -BoundParameters $PSBoundParameters
    $4logfile = $functionCallParameters.Parameters | Out-String
    Write-Log -Message "    >> Used parameter: $4logfile"

    If (-not $AS2GoDemo) { 
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
        $Script:BestDCs = Set-BestDomainController
    }
        
    If (-not $SkipClearHost) { Clear-Host }
        
    Update-WindowTitle -NewTitle $Script:Phase07
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase07

    Show-CurrentPhase -Phase "phase_07.html"
    If (-not $SkipClearHost) { Clear-Host }
    
    Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase07.toupper())"
    Write-AS2GoOutput -Type  Bullet "Reuse captured NTLM hashes to authenticate via Pass-the-Hash"
    Write-AS2GoOutput -Type  Bullet "Reuse stolen Kerberos tickets to authenticate via Pass-the-Ticket"
    Write-AS2GoOutput -Type  Bullet "Roast Kerberos service tickets to recover weak (service) account passwords"
    Write-AS2GoOutput -Type  Bullet "Abuse an ESC1-vulnerable certificate template to impersonate privileged users"
    Write-AS2GoOutput -Type  Bullet "Gain remote code execution as Local System using PsExec"
    Write-AS2GoOutput -Type  Bullet "Extract credentials from process memory"

    $Script:helpKerberoasting = "Run a Kerberoasting attack to request and crack service account TGS tickets."
    $Script:helpESC1 = "Abuse Misconfigured Certificate Template Attack (ESC1)."
    $Script:helpPsExec = "Abuse PsExec Attack running as Local System (NT AUTHORITY\SYSTEM)."
    $Script:helpPassTheTicket = "Abuse Pass-the-Ticket Attack."
    $Script:helpPassTheHash = "Abuse Pass-the-Hash Attack."
    $Script:helpSkip = "Skip Privilege Escalation."
    $script:helpMemoryAccess = "Abuse Memory Access for Credential Theft."
    $Script:helpEnableMemoryAccess = "Enable Memory Access for Credential Theft."
    


    Do {
        # If ($skipstep) { break }     

        Set-NewColorSchema -NewStage $Script:InitialStart
        If ($unattended) {
            $PrivilegeEscalation = $PrivilegeEscalation
        }
        else {
            $null = New-PrivilegeEscalationRecommendation -computer $env:COMPUTERNAME
        }


        Write-AS2GoOutput -Type Header -Message "Select an Attack Technique"

        Write-Host "  H " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Pass-the-Hash Attack" -NoNewline; Write-Host " ** Coming Soon **" -ForegroundColor Yellow
        Write-Host "  T " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Pass-the-Ticket Attack"
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
            $message = "Select the attack technique to execute. Options with unmet requirements are hidden."
            
            $Script:helpPassTheHash = $null 
            $script:helpMemoryAccess = $null 
            $Script:helpEnableMemoryAccess = $null 
            
            $Options = @(
                [pscustomobject] @{
                    Label = "&Kerberoasting"
                    Help  = $Script:helpKerberoasting
                    Value = "Kerberoasting"
                },
                [pscustomobject] @{
                    Label = "ESC&1"
                    Help  = $Script:helpESC1
                    Value = $Script:PtC 
                },
                [pscustomobject] @{
                    Label = "PSE&xec"
                    Help  = $Script:helpPsExec
                    Value = "X"
                },
                [pscustomobject] @{
                    Label = "Pt&T"
                    Help  = $Script:helpPassTheTicket
                    Value = $Script:PtT
                },
                [pscustomobject] @{
                    Label = "Pt&H"
                    Help  = $Script:helpPassTheHash
                    Value = $Script:PtH
                },
                [pscustomobject] @{
                    Label = "&Memory Access"
                    Help  = $Script:helpMemoryAccess
                    Value = "M"
                },
                [pscustomobject] @{
                    Label = "&Enable Memory Access"
                    Help  = $Script:helpEnableMemoryAccess
                    Value = "E"
                },
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = $Script:helpSkip
                    Value = "S"
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        }

        If ($answer -eq $Script:PtH) {
            #Starting Pass-the-Hash (PtH) Attack on VictimPC

            Show-CurrentPhase -Phase "phase_07_PtH.html"  
            Invoke-PtHAttack
        }
        elseif ($answer -eq $Script:PtT) {

            Show-CurrentPhase -Phase "ESC_PtT.html" 
            Invoke-PassTheTicketAttack
        }
        elseif ($answer -eq $Script:PtC  ) {

            Invoke-PrivilegeEscalationViaESC1
        }
        elseif ($answer -eq "Kerberoasting") {

            Invoke-KerberoastingAttack
        }
        elseif ($answer -eq "M") {

            New-CredentialTheftThroughMemoryAccess
        }
        elseif ($answer -eq "E") {

            Set-UseLogonCredential
        }
        elseif ($answer -eq "X") {

            Invoke-PrivilegeEscalationViaLocalSystem
        }
        else {
            Write-AS2GoOutput -Type Info -Message "Privilege Escalation was skipped."
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

    Measure-FunctionRuntime -End -details $info
}
