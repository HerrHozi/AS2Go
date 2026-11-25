<#
.SYNOPSIS
Displays a menu prompt and returns the selected option.

.DESCRIPTION
Builds a console menu from the supplied options, collects the user's selection, and returns
the corresponding option value. Options with a null, empty, or whitespace-only Help value are
intentionally omitted from the menu.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Builds console choices from the supplied options and returns the selected value.
#>
function Show-DecisionPrompt {
    
    param(
        [string]$Title = "Ready to proceed with this step?",
        [string]$Message = "", #Options with unmet requirements are hidden.",
        [object[]]$Options = @(
            [pscustomobject] @{ 
                Label = "&Yes"
                Help  = 'Continue with this step'
                Value = $Script:Yes 
            },
            [pscustomobject] @{ 
                Label = "&Skip"
                Help  = 'Skip this step'
                Value = $Script:No 
            }
        ),
        [int]$Default = 0
    )
    


    $Info = Measure-FunctionRuntime -Begin

    If ($title.StartsWith("REPEAT |")) {
        [int]$total = 64
        $text = " $title "
        $chars = [Math]::Max(0, [int](($total - $text.Length) / 2))
        $separator = ':' * $chars
        $title = "$separator $text $separator"
    }
    
    $values = @()
    $choices = @()
    foreach ($opt in $Options) {
        if (-not [string]::IsNullOrWhiteSpace($opt.Help)) {
            $values += $opt.value
            $choices += New-Object System.Management.Automation.Host.ChoiceDescription "$($opt.label)", "$($opt.help)"
        }
    }

    Write-host "`n`n[>] $Title" -ForegroundColor $Script:FGCDecisionPrompt
    $result = $Host.UI.PromptForChoice('', $Message, $choices, $Default)

    Write-Log -Message "    >> $Title - User selected option: $( $values[$result])"
    Measure-FunctionRuntime -End -Details $Info 
    
    return $values[$result]
}