<#
.SYNOPSIS
Disables user accounts or enforces password resets for disruption.

.DESCRIPTION
Disables or resets passwords for domain user accounts while preserving the backdoor account,
demonstrating user account manipulation and denial-of-service impact on regular users.

.EXAMPLE
Invoke-UserAccountDisruption
Runs the user account disruption workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
The backdoor account is excluded from account disabling operations.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Disables or resets passwords for user accounts while preserving the backdoor account.
#>
function Invoke-UserAccountDisruption {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Disable user accounts or enforce password resets"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $EmojiIcon = [System.Convert]::toInt32("1F600", 16)
    $Smily = [System.Char]::ConvertFromUtf32($EmojiIcon)

    Write-host "  ... will ignore your new backdoor user " -NoNewline
    Write-host $global:BDUser -ForegroundColor $Script:FGCHighLight -NoNewline
    Write-Host " - $Smily"

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $question = "Do you want to run these steps - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Script:Yes
    }

    If ($answer -eq $Script:Yes) {
        New-UserManipulation
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    Measure-FunctionRuntime -End -Details $info
}
