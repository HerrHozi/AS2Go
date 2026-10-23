<#
.SYNOPSIS
Runs Phase 11 of the AS2Go attack simulation: Exfiltrate Sensitive Data.

.DESCRIPTION
Invoke-ASPhase11ExfiltrateSensitiveData executes the data exfiltration phase in the AS2Go workflow.
It prepares the phase context, updates the window and stage state, optionally displays the phase
visuals, and starts the Phase 11 action chain after interactive confirmation (or automatically in
unattended mode).

The phase simulates an attempt to exfiltrate sensitive data over an SMB share.

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

.PARAMETER SkipSensitiveDataAccess
Skips this phase when set.

.EXAMPLE
Invoke-ASPhase11ExfiltrateSensitiveData

Runs Phase 11 interactively.

.EXAMPLE
Invoke-ASPhase11ExfiltrateSensitiveData -UnAttended -EnableLogging

Runs Phase 11 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase11ExfiltrateSensitiveData -SkipImages -SkipClearHost

Runs Phase 11 without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration
#>
function Invoke-ASPhase11ExfiltrateSensitiveData {

    ################################################################################
    #####                                                                      ##### 
    #####    Run the Attack Phase - Exfiltrate Sensitive Data                  #####                               
    #####                                                                      #####
    ################################################################################
    
    Param (  
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [switch]$SkipSensitiveDataAccess
    )

    $Info = Measure-FunctionRuntime -Begin

    If ($SkipSensitiveDataAccess) {
        Write-Log -Message "Skipped Attack Phase - $($Script:Phase11.toupper())"
    }
    else {
        If (-not $SkipClearHost) { Clear-Host }
        If (-not $AS2GoDemo) { 
            Set-NewColorSchema -NewStage $Script:InitialStart
            Get-AS2GoSettings 
        }
        Update-WindowTitle -NewTitle $Script:Phase11 
        Set-ASConfig -Setting "LastStage" -Value $Script:Phase11 

        Show-CurrentPhase -Phase "phase_11.html"
        If (-not $SkipClearHost) { Clear-Host }
        Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase11.toupper())"
        Write-AS2GoOutput -Type  Bullet "Attempt to exfiltrate sensitive data over an SMB share"

        If ($UnAttended) {
            $answer = $Script:Yes
        }
        else {
            $answer = Show-DecisionPrompt
        }

        If ($answer -eq $Script:Yes) {
            Invoke-Phase11DataExfiltration
        }
    }

    Measure-FunctionRuntime -End -Details $Info
}
