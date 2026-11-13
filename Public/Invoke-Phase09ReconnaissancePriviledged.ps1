<#
.SYNOPSIS
Runs the AS2Go privileged reconnaissance demonstration.

.DESCRIPTION
Phase 09 demonstrates what an elevated account can see after privilege escalation.
An interactive run offers to display services and processes on the logon server
and separately prompts for extended reconnaissance.

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

.PARAMETER UnAttended
Runs extended reconnaissance without the phase prompts and skips the logon server service and process listings.

.PARAMETER Continue
Reserved switch for workflow continuation handling.

.PARAMETER EnableLogging
Enables extended logging for this phase execution.

.PARAMETER SkipImages
Skips visual phase assets (for example, phase HTML images/pages).

.PARAMETER SkipClearHost
Prevents clearing the console during phase execution.

.PARAMETER AS2GoDemo
Uses the settings and forest information already loaded by the AS2Go demo.

.PARAMETER SafeMode
Skips reconnaissance actions.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePrivileged

Runs Phase 09 interactively.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePrivileged -UnAttended -EnableLogging

Runs extended reconnaissance without phase prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase09ReconnaissancePrivileged -SkipImages -SkipClearHost

Runs Phase 09 without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration

.FUNCTIONALITY
Shows how elevated privileges can expose services and running processes on the logon server.
Includes an extended reconnaissance demonstration.
#>
function Invoke-ASPhase09ReconnaissancePrivileged {

    [Alias("ASP09")]
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
      Update-WindowTitle -NewTitle $Script:Phase09
    Show-CurrentPhase -Phase "phase_09.html"

    If (-not $SafeMode) {
        If (-not $AS2GoDemo) {
            Set-NewColorSchema -NewStage $Script:InitialStart
            Get-AS2GoSettings
            Get-forestinfo
        }
    }

    If (-not $SkipClearHost) { Clear-Host }

  

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -Message "Attack Phase - $($Script:Phase09)"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -Message "View services on the logon server with elevated privileges"
    Write-AS2GoOutput -Type Bullet -Message "View running processes on the logon server"
    Write-AS2GoOutput -Type Bullet -Message "Collect additional directory and network information during extended reconnaissance"

    $promptParams = @{}
    if ($safemode) {
        $promptParams.Options = @(
            [pscustomobject]@{
                Label = '&Skip'
                Help  = 'Skip this step in Safe Mode'
                Value = $Script:No
            }
        )
    }
    
    If (-not $UnAttended) {
        $answer = Show-DecisionPrompt @promptParams
    }
    else {
        if ($safemode) {
            $answer = $Script:No
        }
        else {
            $answer = $Script:Yes
        }

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
