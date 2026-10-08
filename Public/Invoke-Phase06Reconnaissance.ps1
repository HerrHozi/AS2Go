<#
.SYNOPSIS
Runs Phase 06 of the AS2Go attack simulation: Reconnaissance.

.DESCRIPTION
Invoke-ASPhase06Reconnaissance executes the reconnaissance phase in the AS2Go workflow.
It prepares phase context, optionally displays phase visuals, and runs baseline reconnaissance
tasks with optional extended reconnaissance.

In AS2Go demo mode, execution is interactive (or unattended) and can be repeated.
Outside demo mode, the phase runs once with default confirmation behavior.

The phase includes actions such as:
- Collecting reconnaissance and configuration data
- Running standard reconnaissance tasks
- Optionally running extended reconnaissance tasks

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
Runs the phase in AS2Go demo mode with interactive demo flow behavior.

.EXAMPLE
Invoke-ASPhase06Reconnaissance

Runs Phase 06 with default behavior.

.EXAMPLE
Invoke-ASPhase06Reconnaissance -UnAttended -EnableLogging

Runs Phase 06 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase06Reconnaissance -AS2GoDemo -SkipImages -SkipClearHost

Runs Phase 06 in demo mode without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration
#>
function Invoke-ASPhase06Reconnaissance {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 06 - Reconnaissance with non privileged user                #####                               
    #####                                                                      #####
    ################################################################################
    
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
    }

    If (-not $SkipClearHost) { Clear-Host }

    

    Update-WindowTitle -NewTitle $Script:Phase06
    #Set-ASConfig -Setting "LastStage" -Value $Script:Phase06
    If (-not $SkipImages) { Show-Phases -Phase "phase_006.html" }
    Do {
        # If ($skipstep) { break }     
        If (-not $SkipClearHost) { Clear-Host }
        
        Invoke-Output -T Header -M "Attack Phase - $($Script:Phase06.toupper())"

        Write-Host "       try to collect reconnaissance and configuration data         "

        If ($AS2GoDemo) {
            If ($UnAttended) {
                $answer = $Script:Yes
            }
            else {
                $question = "Would you like to run this step - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $Script:Yes
            }
        }
        else {
            $answer = $Script:Yes
        }

        If ($answer -eq $Script:Yes) {
            Start-Reconnaissance
            $reconnaissance = $Script:No

            If ($UnAttended) {
                $answer = $reconnaissance
            }
            else {
                $question = "Further reconnaissance tasks - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $reconnaissance
            }

            If ($answer -eq $Script:Yes) {
                Start-ReconnaissanceExtended
            }
        }
        elseIf ($answer -eq $Script:Exit) {
            Stop-AS2GoDemo
        }
        else {
        }

        If (-not $AS2GoDemo) { break }
        #        If (-not $SkipClearHost) { Clear-Host }
        #        Invoke-Output -T Header -M "??? REPEAT | Attack Phase - $($Script:Phase06)  ???"

        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
            $title = "REPEAT | Attack Phase - $($Script:Phase06)"
            $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }

    } Until ($repeat -eq $Script:No)  

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
