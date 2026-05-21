function Get-Honeytoken {

    ################################################################################
    #####                                                                      ##### 
    #####    Check if a honeytoken was selected                                #####                             
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type H1 -Message "`nCurrent HoneyToken"
    
    $previousDN = Get-ASConfig -Setting "BreakGlassAccount"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        Invoke-Output -Type Bullet -Message "Identified HoneyToken" -TM $previousCN
    }
    else {
        Invoke-Output -Type Warning -Message "No Honeytoken identified."
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}