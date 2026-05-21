Function Show-Phases {

    Param([string]$Phase)

    ################################################################################
    #####                                                                      ##### 
    #####    Show current phase in the kill chain - as HTML page               #####
    #####                                                                      #####
    ################################################################################
    
    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $fullpath = Join-Path $Script:ASPhases -ChildPath $Phase  
    Invoke-Item $fullpath
    
    Write-Log -Message "    Opened File: $fullpath"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
