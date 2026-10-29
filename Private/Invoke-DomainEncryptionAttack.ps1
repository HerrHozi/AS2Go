<#
.SYNOPSIS
Encrypts critical Domain Controller assets for strategic leverage.

.DESCRIPTION
Launches a ransomware demonstration that encrypts critical files on Domain Controllers to
demonstrate data confidentiality impact and extortion capabilities of domain compromise.

.EXAMPLE
Invoke-DomainEncryptionAttack
Runs the domain encryption attack workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Encryption is performed on explicitly authorized target systems only.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Encrypts critical Domain Controller files to demonstrate ransomware impact and leverage.
#>
function Invoke-DomainEncryptionAttack {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Encrypt critical Domain Controller assets for strategic leverage"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $question = "Do you want to run this attack - Y or N? Default "
        $answer = $Script:Yes
    }

    If ($answer -eq $Script:Yes) {
        New-RansomwareAttack -BackupShare $Script:ASBackupShare
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    Measure-FunctionRuntime -End -Details $info
}
