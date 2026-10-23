<#
.SYNOPSIS
Writes a named setting to the AS2Go JSON configuration.

.DESCRIPTION
Updates an existing configuration value or adds a new setting, then saves the JSON file.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Updates an existing setting or adds it, then saves the JSON configuration.
#>
Function Set-ASConfig {

    Param(
        [string] $Setting, 
        [string]$Value
    )

    $info = Measure-FunctionRuntime -Begin

    $json = Get-Content -Path $Script:ConfigFile  | ConvertFrom-Json
    $settingEntry = $json.DefaultParameter.Setting | Where-Object { $_.Name -eq $Setting } | Select-Object -First 1
    if ($settingEntry) {
        $settingEntry.Value = $Value
    }
    else {
        $json.DefaultParameter[0].Setting += [PSCustomObject]@{
            Name  = $Setting
            Value = $Value
        }
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:ConfigFile -Force

    Write-Log -Message "    >> Set '$Setting' to '$Value'"

    Measure-FunctionRuntime -End -details $info
}

