<#
.SYNOPSIS
Runs the AS2Go reconnaissance demonstration with a standard domain user.

.DESCRIPTION
Phase 06 demonstrates what a standard domain user can learn from Active Directory.
The baseline demonstration shows which directory information is visible to that account.
In an interactive run, you can also choose to run extended reconnaissance.

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

.PARAMETER UnAttended
Runs baseline reconnaissance without the phase prompts and skips extended reconnaissance.

.PARAMETER Continue
Reserved switch for workflow continuation handling.

.PARAMETER EnableLogging
Enables extended logging for this phase execution.

.PARAMETER SkipImages
Skips visual phase assets (for example, phase HTML images/pages).

.PARAMETER SkipClearHost
Prevents clearing the console during phase execution.

.PARAMETER AS2GoDemo
Uses the settings already loaded by the AS2Go demo.

.PARAMETER SafeMode
Skips reconnaissance actions.

.EXAMPLE
Invoke-ASPhase06Reconnaissance

Runs Phase 06 with default behavior.

.EXAMPLE
Invoke-ASPhase06Reconnaissance -UnAttended -EnableLogging

Runs baseline reconnaissance without phase prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase06Reconnaissance -AS2GoDemo -SkipImages -SkipClearHost

Runs Phase 06 in demo mode without phase visuals and without clearing the host.

.NOTES
Part of: AS2Go attack phase orchestration

.FUNCTIONALITY
Shows what a standard domain user can discover 
about domain administrators, computers, and domain controllers.
#>
function Invoke-ASPhase06Reconnaissance {


    [Alias("ASP06")]
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
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase06Reconnaissance' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }


    $Info = Measure-FunctionRuntime -Begin

    If (-not $AS2GoDemo) {
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
    }

    If (-not $SkipClearHost) { Clear-Host }


    Update-WindowTitle -NewTitle $Script:Phase06
    #Set-ASConfig -Setting "LastStage" -Value $Script:Phase06
    Show-CurrentPhase -Phase "phase_06.html"
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -Message "Attack Phase - $($Script:Phase06.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -Message "List domain administrators visible to a standard domain user"
    Write-AS2GoOutput -Type Bullet -Message "List computers registered in Active Directory"
    Write-AS2GoOutput -Type Bullet -Message "Identify domain controllers visible to the same account"


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
        Invoke-Reconnaissance
        $reconnaissance = $Script:No

        If ($UnAttended) {
            $answer = $reconnaissance
        }
        else {
            $question = "Further reconnaissance tasks - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $reconnaissance
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
