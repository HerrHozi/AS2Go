<#
.SYNOPSIS
Runs Phase 09 of the AS2Go attack simulation: Privileged Reconnaissance.

.DESCRIPTION
Invoke-ASPhase09ReconnaissancePriviledged executes a reconnaissance phase focused on privileged
infrastructure context. The function prepares the phase, optionally shows visuals, and performs
interactive or unattended reconnaissance actions against the logon server.

The phase includes tasks such as:
- Listing services on the logon server
- Listing processes on the logon server
- Running extended reconnaissance tasks
- Optionally repeating the phase loop

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
Invoke-ASPhase09ReconnaissancePriviledged

Runs Phase 09 interactively.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePriviledged -UnAttended -EnableLogging

Runs Phase 09 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePriviledged -SkipImages -SkipClearHost

Runs Phase 09 without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration
#>
function Invoke-Phase09ReconnaissancePriviledged {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 09 - Reconnaissance - After Privileged Escalation           #####                                        
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
        Get-forestinfo
    }

    If (-not $SkipClearHost) { Clear-Host }

    Update-WindowTitle -NewTitle $Script:Phase09
    #Set-ASConfig -Setting "LastStage" -Value $Script:Phase06
    If (-not $SkipImages) { Show-Phases -Phase "phase_009.html" }

    Do {
        # If ($skipstep) { break }     
        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -T Header -M "Attack Phase - $($Script:Phase09)"
        Invoke-Output -T Bullet -M "Use the newly gained privileges to collect reconnaissance and configuration data from the current logon server."
 

        If ($UnAttended) {
            $answer = $Script:Yes
        }
        else {
            $question = "Would you like to run this step - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $Script:Yes
        }

        If ($answer -eq $Script:Yes) {
    
            If (-not $SkipClearHost) { Clear-Host }

            Invoke-output -Type Header -Message "Show Services and Processes on Logon Server"
            
            $server = $env:LOGONSERVER.replace("\", "")

            Write-Host      -NoNewline "  Commands: "
            Write-Highlight -Text " Get-Service ", "-ComputerName ", "$server ", "| " , "Out-GridView ", "-Title " , "Services  on $server"`
                -Color $fgcC, $fgcS, $fgcV, $fgcF, $fgcC, $fgcS, $fgcV

            Write-Host      -NoNewline "            " 
            Write-Highlight -Text " Get-Process ", "-ComputerName ", "$server ", "| " , "Out-GridView ", "-Title " , "Processes on $server"`
                -Color $fgcC, $fgcS, $fgcV, $fgcF, $fgcC, $fgcS, $fgcV 
            Write-Host ""


            If ($UnAttended) {
                $answer = $Script:No
            }
            else {
                $question = "Do you want to run these steps - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $Script:Yes
            }

            If ($answer -eq $Script:Yes) {
                Invoke-Command -ComputerName $server -ScriptBlock { Get-Service | Sort-Object Name } | Out-GridView -Title "Services on $server"
                Invoke-Command -ComputerName $server -ScriptBlock { Get-Process | Sort-Object Name } | Out-GridView -Title "Processes on $server"
            } 

            If ($UnAttended) {
                $answer = $Script:Yes
            }
            else {
                $question = "Further reconnaissance tasks - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $Script:Yes
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

        #If (-not $SkipClearHost) { Clear-Host }

        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
            $title = "REPEAT | Attack Phase - $($Script:Phase09)"
            $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }
   
    } Until ($repeat -eq $Script:No)  

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
