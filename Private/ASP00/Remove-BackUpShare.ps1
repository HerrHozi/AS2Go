<#
.SYNOPSIS
Removes the AS2Go AD-Backup share and its folder from the configured server.

.DESCRIPTION
Resolves the target server from the AS2GoAppServer/BackupShare configuration settings (or the
supplied Server parameter), removes the AD-Backup SMB share, and deletes the underlying
C:\temp\as2go folder.

.PARAMETER Server
Target server hosting the AD-Backup share. Falls back to the AS2GoAppServer configuration
setting, or is parsed from the BackupShare UNC path, when omitted.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Removes the AD-Backup SMB share and its backing folder from the configured server.
#>
function Remove-BackUpShare {

    param(
        [string] $Server
    )

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Removing the AS2Go backup share"

    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Get-ASConfig -Setting "AS2GoAppServer"
    }
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $BackupShare = Get-ASConfig -Setting "BackupShare"
        if ($BackupShare -match '^\\\\([^\\]+)\\') {
            $Server = $Matches[1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($Server)) {
        Write-AS2GoOutput -Type Warning -Message "No server is configured for the backup share (AS2GoAppServer/BackupShare); nothing to remove."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Remove the 'AD-Backup' share and its folder on '$Server'."; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&No"; Help = "Skip removing the backup share."; Value = $Script:No }
    )
    $answer = Show-DecisionPrompt -Message "Remove the AS2Go backup share on '$Server'?" -Options $Options -Default 1

    if ($answer -ne $Script:Yes) {
        Write-AS2GoOutput -Type Info -Message "Skipped removing the backup share."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    try {
        Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
            Remove-SmbShare -Name "AD-Backup" -Confirm:$false -ErrorAction SilentlyContinue
            Remove-Item -Path "C:\temp\as2go" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-AS2GoOutput -Type Success -Message "Removed the 'AD-Backup' share and its folder on '$Server'."
    }
    catch {
        Write-AS2GoOutput -Type Warning -Message "Failed to remove the backup share on '$Server': $_"
    }

    Measure-FunctionRuntime -End -Details $Info
}
