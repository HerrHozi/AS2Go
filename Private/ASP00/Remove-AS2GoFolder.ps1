<#
.SYNOPSIS
Removes the local AS2Go public data folder.

.DESCRIPTION
Deletes the entire $env:PUBLIC\AS2Go folder, including the configuration file, logs, tools,
tickets, and exfiltration data. Run this last, since Remove-AS2GoLab's other steps depend on the
configuration file this folder contains.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Deletes the complete local $env:PUBLIC\AS2Go folder (config, tools, logs, tickets, exfiltration data).
#>
function Remove-AS2GoFolder {

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Removing the local AS2Go data folder"

    if (-not (Test-Path -Path $script:AS2GoPublicDir)) {
        Write-AS2GoOutput -Type Warning -Message "'$script:AS2GoPublicDir' does not exist; nothing to remove."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Permanently delete '$script:AS2GoPublicDir', including the AS2Go configuration file."; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&No"; Help = "Skip removing the local AS2Go data folder."; Value = $Script:No }
    )
    $answer = Show-DecisionPrompt -Message "Permanently delete '$script:AS2GoPublicDir'?" -Options $Options -Default 1

    if ($answer -ne $Script:Yes) {
        Write-AS2GoOutput -Type Info -Message "Skipped removing the local AS2Go data folder."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    try {
        Remove-Item -Path $script:AS2GoPublicDir -Recurse -Force -ErrorAction Stop
        Write-AS2GoOutput -Type Success -Message "Removed '$script:AS2GoPublicDir'."
    }
    catch {
        Write-AS2GoOutput -Type Warning -Message "Failed to remove '$script:AS2GoPublicDir': $_"
    }

    Measure-FunctionRuntime -End -Details $Info
}
