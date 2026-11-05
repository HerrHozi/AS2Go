<#
.SYNOPSIS
Runs Phase 10 of the AS2Go attack simulation: Access Sensitive Data.

.DESCRIPTION
Invoke-ASPhase10AccessSensitiveData executes the sensitive data access phase in the AS2Go workflow.
It prepares the phase context, updates the window and stage state, optionally displays phase visuals,
and runs the Phase 10 steps after interactive confirmation (or automatically in unattended mode).

The phase demonstrates actions such as:
- Enumerating available network shares on a domain controller
- Enumerating content of exposed backup shares
- Using a sample password file to demonstrate the risks of storing passwords in plaintext
- Attempting to open a command console on a configured application server

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

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Demonstrates access to sensitive data through network shares and an application-server console using fake data.
Uses a sample password file to illustrate why passwords should never be stored in plaintext.
#>
function Invoke-ASPhase10AccessSensitiveData {

    ################################################################################
    #####                                                                      #####
    #####    Run the Attack Phase - Access Sensitive Data                      #####
    #####                                                                      #####
    ################################################################################
    [Alias("ASP10")]
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
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase10AccessSensitiveData' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }


    $Info = Measure-FunctionRuntime -Begin
    Show-CurrentPhase -Phase "phase_10.html"

    If (-not $SkipClearHost) { Clear-Host }
    If (-not $AS2GoDemo) {
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
    }
    Update-WindowTitle -NewTitle $Script:Phase10
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase10


    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Attack Phase - $($Script:Phase10.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type  Bullet "Enumerate available network shares on a domain controller"
    Write-AS2GoOutput -Type  Bullet "Enumerate the configured backup share containing simulated data"
    Write-AS2GoOutput -Type  Bullet "Open an application-server console to inspect a sample plaintext password file"

    If ($UnAttended) {
        $answer = $Script:Yes
        if ($SafeMode) {
            $answer = $Script:No
        }
    }
    else {
        $promptParams = @{}
        if ($SafeMode) {
            $promptParams.Options = @(
                [pscustomobject]@{
                    Label = '&Skip'
                    Help  = 'Skip this step in Safe Mode'
                    Value = $Script:No
                }
            )
        }
        $answer = Show-DecisionPrompt @promptParams
    }

    
    
    If ($answer -eq $Script:Yes) {
        $server = $($Script:ASBackupShare).Split(".")[0]
        $fakeditfile = Join-Path -Path $Script:ASBackupShare -ChildPath "ntds.dit"


        Write-AS2GoOutput -Type Header -Message "Starting with Share Enumeration"

        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text "net ", "view ", "$server" `
            -Color $fgcC, $fgcF, $fgcV
        Write-Host ""

        try {
            Get-ChildItem -path $ASModulePath -Recurse | out-file $fakeditfile
        }
        catch {
            <#Do this if a terminating exception happens#>
        }


        Invoke-Command -ScriptBlock { net view $server } | Out-Host

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        Write-AS2GoOutput -Type Header -Message "Starting Enumeration of Share Content"
        Get-DirContent -Path $Script:ASBackupShare

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message  "Try to open cmd console on $Script:ASAppServer"

        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text "Start-Process ", ".\PsExec.exe ", "-ArgumentList ", """\\$Script:ASAppServer -accepteula cmd.exe""" `
            -Color $fgcC, $fgcF, $fgcS, $fgcV
        Write-Host ""

        # Prepare the sample file on the server where the command prompt runs.
        $sensitiveFileShare = '\\{0}\{1}' -f $Script:ASAppServer, ($Script:SensitiveInfos -replace '^([A-Za-z]):', '$1$')
        try {
            New-Item -Path (Split-Path -Path $sensitiveFileShare -Parent) -ItemType Directory -Force -ErrorAction Stop | Out-Null
            if (-not (Test-Path -LiteralPath $sensitiveFileShare -ErrorAction Stop)) {
                "AS2Go simulated sensitive information.`n Use xyz for application purposes.`nNo real credentials are stored in this file.`n" |
                Out-File -LiteralPath $sensitiveFileShare -Encoding utf8 -NoClobber -ErrorAction Stop
            }
        }
        catch {
            Write-Warning "Could not prepare the simulated sensitive file: $($_.Exception.Message)"
        }
        $sensitiveFileCommand = 'more "{0}"' -f $Script:SensitiveInfos
        try {
            Write-Output $sensitiveFileCommand | Set-Clipboard
        }
        catch {
            Write-Output $sensitiveFileCommand | clip
        }

        If ($UnAttended) { Start-Sleep 2 } else { Pause }

        $tool = Join-Path -Path $Script:ASTools -ChildPath "PsExec.exe"
        Start-Process $tool -ArgumentList "\\$Script:ASAppServer -accepteula cmd.exe"

        Write-AS2GoOutput -Type Bullet -Message "Inspect the sample password file to see why passwords should never be stored in plaintext"

        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text "more ", $Script:SensitiveInfos `
            -Color $fgcC, $fgcV
        Write-Host ""

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        If (-not $SkipClearHost) { Clear-Host }
    }
    Measure-FunctionRuntime -End -Details $Info
}
