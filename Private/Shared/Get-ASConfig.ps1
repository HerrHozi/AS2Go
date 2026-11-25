<#
.SYNOPSIS
Reads a named setting from the AS2Go JSON configuration.

.DESCRIPTION
Loads the AS2Go JSON configuration and returns the value associated with the requested setting.

.PARAMETER DPAPI
Decrypts a value saved with Set-ASConfig -DPAPI on this Windows computer. Only the setting name is logged.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Loads the configured value from the module's JSON settings file and returns it.
#>
Function Get-ASConfig {

    ################################################################################
    #####                                                                      ##### 
    #####             Read Setting from JSON File                              #####
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $Setting,
        [switch] $DPAPI
    )

    $info = Measure-FunctionRuntime -Begin

    $json = Get-Content -Path $Script:ConfigFile | ConvertFrom-Json
    $value = ($json.DefaultParameter.Setting | Where-Object { $_.Name -eq $Setting }).Value

    if ($DPAPI) {
        if ($null -ne $value) {
            try {
                $encrypted = [Convert]::FromBase64String($value)
                $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
                    $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine
                )
                $value = [System.Text.Encoding]::UTF8.GetString($decrypted)
            }
            catch {
                Write-Log -Message "    >> Unable to decrypt configuration setting '$Setting' with machine-scoped DPAPI: $($_.Exception.Message)"
                $value = $null
            }
        }
        Write-Log -Message "    >> using protected setting '$Setting'"
    }
    else {
        Write-Log -Message "    >> using $Setting with value $value"
    }

    Measure-FunctionRuntime -End -details $info

    return $value
}
