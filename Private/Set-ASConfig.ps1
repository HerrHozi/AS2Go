<#
.SYNOPSIS
Writes a named setting to the AS2Go JSON configuration.

.FUNCTIONALITY
Updates an existing setting or adds it, then saves the JSON configuration.
#>
Function Set-ASConfig {

    ################################################################################
    #####                                                                      ##### 
    #####         Update value in JSON File                                    #####
    #####                                                                      #####
    ################################################################################

    Param([string] $Setting, [string]$Value)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

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
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}

