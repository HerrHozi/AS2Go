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
Displays an AS2Go presentation introduction and agenda, then prompts for a slide-navigation choice.

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
    
    Write-AS2GoOutput -Type Header -Message "AS2Go | Attack Scenario to Go"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    #Write-AS2GoOutput TextMaker -Message "This session covers version"  -TextMaker $($ASModuleManifest.version).ToString()
    Write-AS2GoOutput TextMaker -Message "Speaker:"  -TextMaker "Holger Zimmermann (HerrHozi)"
    Write-AS2GoOutput -Type H1 -Message "Agenda:`n"
    Write-AS2GoOutput -Type Bullet -Message "Topic 1"
    Write-AS2GoOutput -Type Bullet -Message "Topic 2"


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




<#

Analyze the PowerShell function below and update its existing `.FUNCTIONALITY` help text in the corresponding source file. 
Place `.FUNCTIONALITY` as the final help section, immediately before the comment-based help closing marker. 
Do not modify any other code or comments.

Analysis
1. Inspect the main function’s complete implementation and control flow.
2. Identify and analyze all directly called repository functions (call depth 1); inspect their implementations when available.
3. Follow conditions, selections, prompts, attempted actions, user-visible output, and verification steps.
4. Ignore setup, logging, error handling, and implementation details unless they materially affect the phase’s purpose.
5. Do not analyze deeper dependencies unless needed to understand a direct call.

Writing rules
- Describe what users can expect the function or phase to accomplish, using concise English.
- Use up to 3 lines, with no more than 120 characters per line and 360 characters total, including spaces and punctuation.
- Use as few lines as needed. Break lines at natural sentence boundaries; do not split words.
- Prioritize meaningful security actions, techniques, and observable outcomes.
- Distinguish completed actions from attempted, conditional, or optional actions.
- Do not claim success where the implementation only attempts an action or handles failure.
- Avoid generic phrasing, function-name repetition, and unsupported claims.
- Use terminology consistent with the AS2Go project.

Output
- Return only the `.FUNCTIONALITY` description: no tag, quotation marks, explanation, bullets, or Markdown.
- If the implementation does not provide enough information, ask one concise clarification instead of guessing.

#>