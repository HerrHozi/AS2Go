<#
.SYNOPSIS
Runs Phase 12 of the AS2Go attack simulation: Domain Compromise and Persistence.

.DESCRIPTION
Invoke-ASPhase12DomainCompromisePersistence executes the final attack phase in the AS2Go workflow.
It prepares the phase context, shows the phase banner, and starts the Phase 12 action chain after
interactive confirmation (or automatically in unattended mode).

The phase demonstrates persistence and impact actions such as:
- Creating a persistent backdoor domain account
- User account manipulation (disable/reset)
- Tier 0 group membership manipulation
- Group Policy Template tampering
- Encrypting backup files on a domain controller
- Exporting a DPAPI master key
- Forging a Kerberos Golden Ticket
- Rebooting available domain machines

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

.PARAMETER DeveloperMode
Developer convenience mode.
When set, this switch enables logging and automatically skips images and host clearing.

.PARAMETER SkipDomainPersistence
Skips this phase when set.

.EXAMPLE
Invoke-ASPhase12DomainCompromisePersistence

Runs Phase 12 interactively.

.EXAMPLE
Invoke-ASPhase12DomainCompromisePersistence -UnAttended -EnableLogging

Runs Phase 12 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase12DomainCompromisePersistence -DeveloperMode

Runs Phase 12 with developer defaults (logging on, images skipped, no clear-host).

.NOTES
Alias: P12, Compromise
Part of: AS2Go attack phase orchestration

.FUNCTIONALITY
Executes the Domain Compromise and Persistence phase within an Active Directory environment.
Demonstrates various attack techniques and persistence mechanisms.
#>
function Invoke-ASPhase12DomainCompromisePersistence {

    ################################################################################
    #####                                                                      ##### 
    #####    Run the Attack Phase - Domain Compromise & Persistence            #####                               
    #####                                                                      #####
    ################################################################################
    [Alias("ASP12", "Compromise")]
    Param (  
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [switch]$SkipDomainPersistence,
        [switch]$DeveloperMode,
        [validateSet("Encrypt", "Reboot", "BackdoorUser", "GPT", "UserManipulation", "GroupManipulation")]
        [String]$DomainPersistence
    )
    $info = Measure-FunctionRuntime -Begin
    
    $functionCallParameters = Get-FunctionCallParameters -FunctionName $MyInvocation.MyCommand.Name -BoundParameters $PSBoundParameters
    $4logfile = $functionCallParameters.Parameters | Out-String
    Write-Log -Message "    >> Used parameter: $4logfile"

    If ($DeveloperMode) {
        $SkipImages = $true
        $SkipClearHost = $true
        $EnableLogging = $true
    }
        
    If ($SkipDomainPersistence) {
        Write-Log -Message "Skipped Attack Phase - $($Script:Phase12.toupper())"
    }
    else {

        If (-not $SkipClearHost) { Clear-Host }
        If (-not $AS2GoDemo) {
            Clear-ExfiltrationFolder 
            Set-NewColorSchema -NewStage $Script:InitialStart
            Get-AS2GoSettings
        }
        
        Update-WindowTitle -NewTitle $Script:Phase12 
        
        Set-ASConfig -Setting "LastStage" -Value $Script:Phase12

        Show-CurrentPhase -Phase "phase_12.html"
        
        Set-NewColorSchema -NewStage $Script:InitialStart
        If (-not $SkipClearHost) { Clear-Host }
        Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase12.toupper())"
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
        Write-AS2GoOutput -Type  Bullet "Create a persistent backdoor domain account"
        Write-AS2GoOutput -Type  Bullet "Perform user account manipulation (disable accounts and/or reset passwords)"
        Write-AS2GoOutput -Type  Bullet "Perform Tier 0 group membership manipulation (remove all admins except backdoor and break-glass accounts)"
        Write-AS2GoOutput -Type  Bullet "Tamper with Group Policy Template (GPT) files to push malicious settings"
        Write-AS2GoOutput -Type  Bullet "Encrypt backup files stored on the domain controller"
        Write-AS2GoOutput -Type  Bullet "Export the DPAPI master key for offline decryption of secrets"
        Write-AS2GoOutput -Type  Bullet "Forge a Kerberos Golden Ticket for long-term domain persistence"
        Write-AS2GoOutput -Type  Bullet "Reboot all available machines in the domain"

        If ($UnAttended) {
            $answer = $Script:Yes
        }
        else {
            $answer = Show-DecisionPrompt
        }

        If ($answer -eq $Script:Yes) {
            If (-not $AS2GoDemo) { 
                Show-ForestOverview 
                Get-ForestInfo
                $Script:MoGPO = Test-PoSHModuleAvailability -PSModule "GroupPolicy" 
            }
            Invoke-Phase12DomainCompromise 
        }
    }

    Measure-FunctionRuntime -End -Details $info
}
