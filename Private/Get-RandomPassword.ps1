function Get-RandomPassword {

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $chars = "abcdefghijkmnopqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ1234567890".ToCharArray()
    $nums = "1234567890".ToCharArray()
    $schars = "+-$!()".ToCharArray()

    $newPassword = ""
    1..9 | ForEach-Object { $newPassword += $chars | Get-Random }
    1..1 | ForEach-Object { $newPassword += $nums | Get-Random }
    1..1 | ForEach-Object { $newPassword += $schars | Get-Random }
    1..3 | ForEach-Object { $newPassword += $chars | Get-Random }
    1..1 | ForEach-Object { $newPassword += $nums | Get-Random }
    1..1 | ForEach-Object { $newPassword += $schars | Get-Random }
    Write-Log -Message "    >> New Password: $newPassword"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
    
    return $newPassword
}
