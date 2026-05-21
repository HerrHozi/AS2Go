function Add-ASConfig {

    ################################################################################
    #####                                                                      ##### 
    #####    Add an item to a json file.                                       #####                                
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $Setting,
        [string] $Value
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $json = Get-Content -Path $Script:ConfigFile | ConvertFrom-Json
    
    $existingKey = $json.DefaultParameter.Setting | Where-Object { $_.Name -eq $Name }
    
    if ($existingKey) {
        Write-Log -Message "    >> Key '$Name' exist already, please use Set-KeyValue instead."
        return $false
    }
    
    $newEntry = @{
        Name  = $Name
        Value = $Value
    }
    
    $json.DefaultParameter[0].Setting += $newEntry
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:ConfigFile -Force

    Write-Log -Message "    >> Added '$Name' with value '$Value'"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $true
}