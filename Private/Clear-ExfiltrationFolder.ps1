function Clear-ExfiltrationFolder {

    ################################################################################
    #####                                                                      ##### 
    ##### Clean-up the Exfiltration Folder to remove any files from previous runs #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    # clean-up AS2Go Folder
    New-Item -Path $Script:DefautCleanUpFolder -ItemType Directory  -ErrorAction Ignore | Out-Null
    
    try {
        Get-ChildItem ??-*.* -Path $Script:DefautExfiltrationFolder | Move-Item -Destination $Script:DefautCleanUpFolder -Force | Out-Null
        Get-ChildItem ntds_capi_*.* -Path $Script:DefautExfiltrationFolder | Move-Item -Destination $Script:DefautCleanUpFolder -Force | Out-Null
        Get-ChildItem ntds_legacy_*.* -Path $Script:DefautExfiltrationFolder | Move-Item -Destination $Script:DefautCleanUpFolder -Force | Out-Null
    }
    catch {
    
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}