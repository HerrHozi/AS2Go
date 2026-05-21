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
    ($json.DefaultParameter.Setting | Where-Object { $_.Name -eq $Setting }).Value = $Value
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:ConfigFile -Force

    Write-Log -Message "    >> Set '$Setting' to '$Value'"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
