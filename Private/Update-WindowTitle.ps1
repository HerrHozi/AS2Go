function Update-WindowTitle {

    Param(
        [Parameter(Mandatory = $True)]
        [string]$NewTitle
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################




    $host.ui.RawUI.WindowTitle = $NewTitle
    Write-Log -Message "    >> Changed window title to $NewTitle"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
