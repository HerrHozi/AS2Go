<#
.SYNOPSIS
Small PowerShell Helpers That Make Better Demo Code.

.DESCRIPTION
While developing AS2Go, my PowerShell module for Active Directory attack simulations in authorized labs, I kept running into the same tasks: formatting output, prompting for choices, displaying commands, and remembering settings.

.PARAMETER EnableLogging
Returns the loaded settings and configuration without displaying the interactive review menu.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
From a CMD demo to a PowerShell 7 module
for Active Directory attack simulation
#>
function Start-PsUserGroupSession {
    
    [Alias("PsUG")]
    Param(
        [switch]$Preview,
        [Alias("StartRecording")]
        [switch] $EnableLogging,
        [switch] $SafeMode
    )
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Start-PsUserGroupSession' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

  
    $info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle "PoSH User Group | AS2Go"
    Initialize-ConsoleColors
    $functionCallParameters = Get-FunctionCallParameters -FunctionName $MyInvocation.MyCommand.Name -BoundParameters $PSBoundParameters
    $4logfile = $functionCallParameters.Parameters | Out-String
    Write-Log -Message "    >> Used parameter: $4logfile"
    
    Write-AS2GoOutput -Type Header -Message "AS2Go | Attack Scenario to Go"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    #Write-AS2GoOutput TextMaker -Message "This session covers version"  -TextMaker $($ASModuleManifest.version).ToString()
    Write-AS2GoOutput TextMaker -Message "Speaker:"  -TextMaker "Holger Zimmermann (HerrHozi)"
    Write-AS2GoOutput -Type H1 -Message "Agenda:"
    Write-AS2GoOutput -Type Bullet -Message "Reusable interactive menus with keyboard shortcuts, default choices, and return values."
    Write-AS2GoOutput -Type Bullet -Message "Consistent logging of function execution and elapsed time."
    Write-AS2GoOutput -Type Bullet -Message "Enable IntelliSense for private PowerShell functions in VS Code."
    Write-AS2GoOutput -Type Bullet -Message "Visual selection of AD objects across domains, with optional Tier 0 highlighting."
    Write-AS2GoOutput -Type Bullet -Message "Consistent console output with headings, highlights, status messages, and integrated logging."
    Write-AS2GoOutput -Type Bullet -Message "incl. Color-coded console display of code without executing it."
    Write-AS2GoOutput -Type Command -Message "  [>] get-command -Module AS2Go | Where-Object {`$_.Name -like 'Start*'}"

    write-as2gooutput -Type Bullet -Message "vd"

    $results = Get-ChildItem -Path . -Filter *.html -Recurse | Get-Random -Count 5

    $title = "Example: Reusable interactive menus with keyboard shortcuts"
    $message = "Select an HTML file."

    $options = New-HelpOptions -InputObject $results -Label "Name" -Help "LastWriteTime" -Value "Fullname"
    $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
    Invoke-Item $answer

    $results = Get-ChildItem -Path . -Filter *.html -Recurse | Get-Random -Count 5
    $options = New-HelpOptions -InputObject $results -Label "Name" -Help "LastWriteTime" -Value "IndexOf" -AddSkip
    $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
    $results[$answer]

    #ctrl + shift + p --> Debug Restart
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