<#
.SYNOPSIS
Writes a named setting to the AS2Go JSON configuration.

.DESCRIPTION
Updates an existing configuration value or adds a new setting, then saves the JSON file.

.PARAMETER DPAPI
Encrypts the value with machine-scoped Windows DPAPI before saving it. Only the setting name is logged.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Updates an existing setting or adds it, then saves the JSON configuration.
#>
Function Set-ASConfig {

    Param(
        [string] $Setting, 
        [string]$Value,
        [switch]$DPAPI
    )

    $info = Measure-FunctionRuntime -Begin

    if ($DPAPI) {
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
            $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
                $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine
            )
            $Value = [Convert]::ToBase64String($encrypted)
        }
        catch {
            throw "Unable to encrypt configuration setting '$Setting' with machine-scoped DPAPI."
        }
    }

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

    if ($DPAPI) {
        Write-Log -Message "    >> Set protected setting '$Setting'"
    }
    else {
        Write-Log -Message "    >> Set '$Setting' to '$Value'"
    }

    Measure-FunctionRuntime -End -details $info
}

