<#
.SYNOPSIS
Purges all privileged group memberships from domain accounts.

.DESCRIPTION
Removes users from all privileged groups in the domain to consolidate exclusive control through
the backdoor account, demonstrating privilege consolidation techniques.

.EXAMPLE
Invoke-PrivilegeGroupPurge
Runs the privilege group purge workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Removes users from all privileged groups to consolidate exclusive control to the backdoor account.
#>
function Invoke-PrivilegeGroupPurge {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Purge all privileged group memberships"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {
        Invoke-GroupManipulation
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    Measure-FunctionRuntime -End -Details $info
}
