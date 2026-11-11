<#
.SYNOPSIS
Runs Phase 07 of the AS2Go attack simulation: Privilege Escalation.

.DESCRIPTION
Invoke-ASPhase07PrivilegeEscalation executes the privilege escalation phase in the AS2Go workflow.
It initializes phase context, optionally shows visuals, and presents an attack selection menu that
can be run interactively or in unattended mode using an automatic recommendation.

Depending on the selected option, the phase can trigger attacks and actions such as:
- Overpass-the-Hash with a captured NTLM hash (PtH)
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
.FUNCTIONALITY
Demonstrates credential reuse, Kerberos ticket abuse, Kerberoasting, and AD CS certificate template abuse.
Supports privilege escalation through ESC1, remote code execution as Local System via PsExec, and credential theft from process memory.
Shows how captured NTLM hashes, stolen Kerberos tickets, and vulnerable certificate templates can grant privileged domain access.
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
        [String]$PrivilegeEscalation,
        [switch]$SafeMode
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
        $Forest = Get-ADForest
        $Script:AllDomainsDetails = $Forest.Domains | ForEach-Object {
            Get-DomainDetails -DomainName $_
        }
    }
        
    If (-not $SkipClearHost) { Clear-Host }
        
    Update-WindowTitle -NewTitle $Script:Phase07
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase07

    Show-CurrentPhase -Phase "phase_07.html"
    If (-not $SkipClearHost) { Clear-Host }
    
    Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase07.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    Write-AS2GoOutput -Type Bullet "Convert captured NTLM hashes into Kerberos tickets via Overpass-the-Hash"
    Write-AS2GoOutput -Type Bullet "Reuse stolen Kerberos tickets to authenticate via Pass-the-Ticket"
    Write-AS2GoOutput -Type Bullet "Request Kerberos service tickets and crack them offline to recover service-account credentials"
    Write-AS2GoOutput -Type Bullet "Abuse an ESC1-vulnerable AD CS certificate template to obtain a certificate for a privileged principal"
    Write-AS2GoOutput -Type Bullet "Obtain remote code execution as Local System using PsExec"
    Write-AS2GoOutput -Type Bullet "Extract credentials from process memory"

    $Script:helpKerberoasting = "Request Kerberos service tickets for SPN accounts and crack them offline to recover service-account credentials."
    $Script:helpESC1 = "Abuse an ESC1-vulnerable AD CS certificate template to obtain a certificate for a privileged principal."
    $Script:helpPsExec = "Execute a PsExec attack to obtain remote code execution as Local System (NT AUTHORITY\SYSTEM)."
    $Script:helpPassTheHash = "Convert captured NTLM hashes into Kerberos tickets to authenticate via Overpass-the-Hash."
    $Script:helpPassTheTicket = "Reuse captured Kerberos tickets to authenticate via Pass-the-Ticket."
    $script:helpMemoryAccess = "Extract credentials from process memory."
    $Script:helpEnableMemoryAccess = "Enable Memory Access for Credential Theft."
    $Script:helpSkip = "Skip Privilege Escalation."

    If (-not $unattended) {
        $answer = Show-DecisionPrompt
        If ($answer -eq $Script:No) { return }
    }



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

        Write-Host "  H " -ForegroundColor Yellow -NoNewline; Write-Host "- for an Overpass-the-Hash Attack"
        Write-Host "  T " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Pass-the-Ticket Attack"
        Write-Host "  K " -ForegroundColor Yellow -NoNewline; Write-Host "- for a Kerberoasting Attack"
        Write-Host "  1 " -ForegroundColor Yellow -NoNewline; Write-Host "- for an AD CS Certificate Template Abuse Attack (ESC1)"
        Write-Host "  X " -ForegroundColor Yellow -NoNewline; Write-Host "- for a PsExec Attack as Local System (NT AUTHORITY\SYSTEM)"
        Write-Host "  M " -ForegroundColor Yellow -NoNewline; Write-Host "- for Credential Theft via Memory Access"
        Write-Host "  E " -ForegroundColor Yellow -NoNewline; Write-Host "- to Enable Memory Access for Credential Theft"

        Write-host "`n  S " -ForegroundColor Yellow -NoNewline; Write-Host "- to skip this step"

        If ($UnAttended) {
            $answer = $PrivilegeEscalation
        }
        else {
        
            $title = "Privilege Escalation"
            $message = "Select the attack technique to execute. Options with unmet requirements are hidden."
            
            #$Script:helpPassTheHash = $null 
            #$script:helpMemoryAccess = $null 
            #$Script:helpEnableMemoryAccess = $null 
            
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
                    Label = "PT&T"
                    Help  = $Script:helpPassTheTicket
                    Value = $Script:PtT
                },
                [pscustomobject] @{
                    Label = "OpT&H"
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
                    Value = $Script:No
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        }

        If ($answer -eq $Script:PtH) {
            Show-CurrentPhase -Phase "phase_07_PtH.html"  
            Invoke-OverPassTheHashAttack
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

            Invoke-PriviledgeEscalationViaMemoryAccess
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

        if ($UnAttended) {
            $answer = $Script:No
        }


   
    } Until ($answer -eq $Script:No)

    Measure-FunctionRuntime -End -details $info
}
