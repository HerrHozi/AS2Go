<#
.SYNOPSIS
Runs Phase 09 of the AS2Go attack simulation: Privileged Reconnaissance.

.DESCRIPTION
Invoke-ASPhase09ReconnaissancePrivileged executes a reconnaissance phase focused on privileged
infrastructure context. The function prepares the phase, optionally shows visuals, and performs
interactive or unattended reconnaissance actions against the logon server.

The phase includes tasks such as:
- Listing services on the logon server
- Listing processes on the logon server
- Running extended reconnaissance tasks
- Running the phase once per invocation

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
Invoke-ASPhase09ReconnaissancePrivileged

Runs Phase 09 interactively.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePrivileged -UnAttended -EnableLogging

Runs Phase 09 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePrivileged -SkipImages -SkipClearHost

Runs Phase 09 without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration
#>
function Invoke-ASPhase09ReconnaissancePrivileged {



    ################################################################################
    #####                                                                      #####
    #####    Phase 09 - Reconnaissance - After Privileged Escalation           #####
    #####                                                                      #####
    ################################################################################

    Param (
        [switch]$Preview,
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [switch]$SafeMode
    )
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase09ReconnaissancePrivileged' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }


    $Info = Measure-FunctionRuntime -Begin

    If (-not $AS2GoDemo) {
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
        Get-forestinfo
    }

    If (-not $SkipClearHost) { Clear-Host }

    Update-WindowTitle -NewTitle $Script:Phase09
    #Set-ASConfig -Setting "LastStage" -Value $Script:Phase06
    Show-CurrentPhase -Phase "phase_09.html"

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -Message "Attack Phase - $($Script:Phase09)"
    Write-AS2GoOutput -Type  H1 -Message "Use the newly gained privileges to collect reconnaissance `nand configuration data from the current logon server."


    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $question = "Would you like to run this step - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Script:Yes
    }

    If ($answer -eq $Script:Yes) {

        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message "Show Services and Processes on Logon Server"
        $Functionality = "Displays services and processes from the current logon server for reconnaissance. `n"
        Write-AS2GoOutput -Type H1 -Message $Functionality

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
            Invoke-ReconnaissanceExtended
        }
    }
    elseIf ($answer -eq $Script:Exit) {
        Stop-AS2GoDemo
    }
    else {
    }

    Measure-FunctionRuntime -End -Details $Info
}
