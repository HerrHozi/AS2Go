function Show-Disclaimer {

    <#
    .SYNOPSIS
    Displays the AS2Go authorization disclaimer and requests explicit consent.

    .DESCRIPTION
    Shows the AS2Go important-notice banner informing the user that real-world attack
    techniques are about to be simulated in a prepared Active Directory environment.
    The user must confirm that they are authorized to run AS2Go in this environment.
    If authorization is not confirmed, the function reports the termination and returns
    the user's decision so the caller can abort.

    .COMPONENT
    Category: Sub Function

    .FUNCTIONALITY
    Presents the authorization disclaimer, prompts for confirmation, and returns the decision.

    .OUTPUTS
    Returns the user's decision ($Script:Yes or $Script:No).

    .EXAMPLE
    PS> $decision = Show-Disclaimer
    Displays the disclaimer and stores the user's authorization decision.
    #>


    $info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -M "AS2Go - SECURITY DISCLAIMER"


    Write-Host "[!] You are about to simulate real-world attack scenarios in a specially prepared Active Directory environment."
    Write-Host "    Real attackers may spend days, weeks, months, or even years achieving what AS2Go demonstrates" -noNewline
    Write-Host " in minutes."  -ForegroundColor Cyan
    Write-Host "`n    Same techniques · Same attack paths · Different timelines`n" -ForegroundColor Cyan
    Write-Host "    Use AS2Go only in explicitly authorized, controlled environments.`n"

$Options = @(
    [pscustomobject]@{
        Label = "&Yes"
        Help  = "I confirm that I have explicit authorization to run AS2Go in this environment."
        Value = $Script:Yes
    },
    [pscustomobject]@{
        Label = "&No"
        Help  = "I do not confirm authorization. AS2Go will exit."
        Value = $Script:No
    }
)

    $title = "Do you confirm that you have explicit authorization to run AS2Go in this environment?"
    $message = ""

    $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 1 -Title $title

    if ($decision -ne $Script:Yes) {
        Write-AS2GoOutput -Type Quit -Message "AS2Go terminated: Explicit authorization was not confirmed."
    }

    Measure-FunctionRuntime -End -Details $info

    return $decision

}