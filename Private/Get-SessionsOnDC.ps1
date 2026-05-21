function Get-SessionsOnDC {

    Param([string]$server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $tool = Join-Path -Path $Script:ASTools -ChildPath "NetSess.exe"
    Invoke-Command -ScriptBlock { param($tool, $server) & $tool $server } -ArgumentList $tool, $server | out-host

    Write-Log -Message "    >> Using DC $server!"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
