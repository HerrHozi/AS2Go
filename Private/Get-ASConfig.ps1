<#
.SYNOPSIS
Reads a named setting from the AS2Go JSON configuration.

.DESCRIPTION
Loads the AS2Go JSON configuration and returns the value associated with the requested setting.

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
        [string] $Setting
    )

    $info = Measure-FunctionRuntime -Begin

    $json = Get-Content -Path $Script:ConfigFile | ConvertFrom-Json
    $value = ($json.DefaultParameter.Setting | Where-Object { $_.Name -eq $Setting }).Value

    Write-Log -Message "    >> using $Setting with value $value"

    Measure-FunctionRuntime -End -details $info

    return $value
}
