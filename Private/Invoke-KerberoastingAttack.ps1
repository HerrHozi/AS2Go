<#
.SYNOPSIS
Runs the AS2Go Kerberoasting stage and optional repeat workflow.

.DESCRIPTION
Updates the window title and saved lab stage, then invokes the Kerberoasting routine.
The routine selects a domain and requests service tickets for accounts matching admincount=1 using Rubeus.
Exports hashes to the configured exfiltration directory and offers to view them.
Attended execution offers to repeat the stage; unattended execution exits the stage after one pass.

.EXAMPLE
Invoke-KerberoastingAttack
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Uses the same Rubeus, domain-context, and initialized module settings as Start-Kerberoasting.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Runs the Kerberoasting stage, requesting service tickets for accounts matching adminCount=1 in a selected domain.
Exports hashes for offline analysis and offers to repeat the stage in attended mode.
#>
function Invoke-KerberoastingAttack {

    ################################################################################
    #####                                                                      ##### 
    #####    Prepare for new Kerberoasting Attack.                             #####
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle $Script:Phase27
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase27
    #Show-CurrentPhase -Phase "phase_07.html"

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -M "Privilege Escalation via Kerberoasting"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

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
    $answer = Show-DecisionPrompt @promptParams
    if ($answer -eq $Script:No) {
        return
    }


    Start-Kerberoasting    

    Measure-FunctionRuntime -End -Details $Info
}
