<#
.SYNOPSIS
Runs Phase 10 of the AS2Go attack simulation: Access Sensitive Data.

.DESCRIPTION
Invoke-ASPhase10AccessSensitiveData executes the sensitive data access phase in the AS2Go workflow.
It prepares the phase context, updates the window and stage state, optionally displays phase visuals,
and starts the Phase 10 action chain after interactive confirmation (or automatically in unattended mode).

The phase demonstrates actions such as:
- Enumerating available network shares on a domain controller
- Enumerating content of exposed backup shares
- Attempting to open a command console on a privileged admin workstation (PAW)

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
Invoke-ASPhase10AccessSensitiveData

Runs Phase 10 interactively.

.EXAMPLE
Invoke-ASPhase10AccessSensitiveData -UnAttended -EnableLogging

Runs Phase 10 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase10AccessSensitiveData -SkipImages -SkipClearHost

Runs Phase 10 without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration
#>
function Invoke-ASPhase10AccessSensitiveData {

    ################################################################################
    #####                                                                      ##### 
    #####    Run the Attack Phase - Access Sensitive Data                      #####                               
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

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ($SkipSensitiveDataAccess) {
        Write-Log -Message "Skipped Attack Phase - $($Script:Phase10.toupper())"
    }
    else {
        If (-not $SkipClearHost) { Clear-Host }
        If (-not $AS2GoDemo) { 
            Set-NewColorSchema -NewStage $Script:InitialStart
            Get-AS2GoSettings 
        }
        Update-WindowTitle -NewTitle $Script:Phase10 
        Set-ASConfig -Setting "LastStage" -Value $Script:Phase10 

        If (-not $SkipImages) { Show-Phases -Phase "phase_010.html" }
        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type  Header -M "Attack Phase - $($Script:Phase10.toupper())"
        Invoke-Output -Type  Bullet "Enumerate available network shares on a domain controller"
        Invoke-Output -Type  Bullet "Enumerate the content of exposed backup shares"
        Invoke-Output -Type  Bullet "Attempt to open a command console on a privileged admin workstation (PAW)"

        If ($UnAttended) {
            $answer = $Script:Yes
        }
        else {
            $answer = Show-DecisionPrompt
        }

        If ($answer -eq $Script:Yes) {
            Start-Phase10DataAccess
        }
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
