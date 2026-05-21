Function Get-ASConfig {

    ################################################################################
    #####                                                                      ##### 
    #####             Read Setting from JSON File                              #####
    #####                                                                      #####
    ################################################################################

    Param([string] $Setting)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    $json = Get-Content -Path $Script:ConfigFile | ConvertFrom-Json
    $value = ($json.DefaultParameter.Setting | Where-Object { $_.Name -eq $Setting }).Value

    Write-Log -Message "    >> using $Setting with value $value"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $value
}
