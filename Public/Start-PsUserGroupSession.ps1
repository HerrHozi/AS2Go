<#
.SYNOPSIS
Verifies and updates global AS2Go settings.

.DESCRIPTION
Loads and normalizes saved settings, refreshes available domain and host defaults, and syncs
the values to script variables. In interactive mode, displays the settings and lets the user
review or edit them; ReadOnly mode returns the settings and configuration without prompting.

.PARAMETER ReadOnly
Returns the loaded settings and configuration without displaying the interactive review menu.

.FUNCTIONALITY
From a CMD demo to a PowerShell 7 module for Active Directory attack simulation.

.COMPONENT
Category: Main Function
#>
function Start-PsUserGroupSession {

    Param(
        [switch] $EnableLogging,
        [switch] $StartRecording
    )
  
    $host.ui.RawUI.WindowTitle = "PoSH User Group | AS2Go"

    $info = Measure-FunctionRuntime -Begin

    Initialize-ConsoleColors
    Set-NewBackgroundColor -BgC $Script:ConsoleBGColor -FgC $Script:ConsoleFGColor

    $functionCallParameters = Get-FunctionCallParameters -FunctionName $MyInvocation.MyCommand.Name -BoundParameters $PSBoundParameters
    $4logfile = $functionCallParameters.Parameters | Out-String
    Write-Log -Message "    >> Used parameter: $4logfile"
    
    Invoke-Output -Type Header -Message "AS2Go | Attack Scenario to Go"
    Invoke-Output -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    #Invoke-Output TextMaker -Message "This session covers version"  -TextMaker $($ASModuleManifest.version).ToString()
    Invoke-Output TextMaker -Message "Speaker:"  -TextMaker "Holger Zimmermann (HerrHozi)"
    Invoke-Output -Type H1 -Message "Agenda:`n"
    Invoke-output -Type Bullet -Message "Topic 1"
    Invoke-output -Type Bullet -Message "Topic 2"


    Write-HighlightedCode -code "get-command -Module 'AS2Go' | Where-Object {`$_.Name -like 'Start*'}"
    #Write-host "get-command -Module 'AS2Go' | Where-Object {`$_.Name -like 'Start*'}"
    
 
    $title = "PoSH User Group | AS2Go | Presentation"
    $message = "Select the action to execute. Options with unmet requirements are hidden."

    $Options = @(
        [pscustomobject] @{
            Label = "&First Slide"
            Help  = 'Go to the first slide'
            Value = 'First'
        },
        [pscustomobject] @{
            Label = "&Previous Slide"
            Help  = 'Go to the previous slide'
            Value = 'Previous'
        },
        [pscustomobject] @{
            Label = "&Next Slide"
            Help  = 'Go to the next slide'
            Value = 'Next'
        },
        [pscustomobject] @{
            Label = "&Last Slide"
            Help  = 'Go to the last slide'
            Value = 'Last'
        },
        [pscustomobject] @{
            Label = "&Exit"
            Help  = '' #Exit the presentation'
            Value = 'Exit'
        }
    )

    $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 2 -Title $title

    If ($answer -eq 'Exit') {
        return
    }

    Measure-FunctionRuntime -End -Details $info

}
