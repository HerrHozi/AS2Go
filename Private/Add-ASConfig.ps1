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

    $Info = Measure-FunctionRuntime -Begin

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
    Measure-FunctionRuntime -End -Details $Info

    return $true
}