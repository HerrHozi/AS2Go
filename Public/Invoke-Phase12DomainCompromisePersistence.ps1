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
        [switch]$DeveloperMode
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

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
        If (-not $SkipImages) { Show-Phases -Phase "phase_012.html" }
        
        Set-NewColorSchema -NewStage $Script:InitialStart
        If (-not $SkipClearHost) { Clear-Host }
        Invoke-Output -Type  Header -M "Attack Phase - $($Script:Phase12.toupper())"
        Invoke-Output -Type  Bullet "Create a persistent backdoor domain account"
        Invoke-Output -Type  Bullet "Perform user account manipulation (disable accounts and/or reset passwords)"
        Invoke-Output -Type  Bullet "Perform Tier 0 group membership manipulation (remove all admins except backdoor and break-glass accounts)"
        Invoke-Output -Type  Bullet "Tamper with Group Policy Template (GPT) files to push malicious settings"
        Invoke-Output -Type  Bullet "Encrypt backup files stored on the domain controller"
        Invoke-Output -Type  Bullet "Export the DPAPI master key for offline decryption of secrets"
        Invoke-Output -Type  Bullet "Forge a Kerberos Golden Ticket for long-term domain persistence"
        Invoke-Output -Type  Bullet "Reboot all available machines in the domain"

        If ($UnAttended) {
            $answer = $Script:Yes
        }
        else {
            $answer = Show-DecisionPrompt
        }

        If ($answer -eq $Script:Yes) {
            If (-not $AS2GoDemo) { 
                Invoke-ForestOverview 
                Get-ForestInfo 
            }
            Start-Phase12DomainCompromise 
        }
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
