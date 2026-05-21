function Get-CachedKerberosTicketsClient {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################
    
    #currently cached Kerberos tickets
    $results = @()
    $results = Invoke-Command -ScriptBlock { klist }
    If ($results.count -ge 5)
    {
        $result = $results[5].Split(":")[-1].trim()
    }
    else {
        $result = "Cached Tickets: (0)"
    }

    Write-Log -Message "    >> found $user - $foundUser!"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result.ToUpper()
}
