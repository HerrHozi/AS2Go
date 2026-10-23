function Get-CachedKerberosTicketsClient {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin
    
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
    Measure-FunctionRuntime -End -Details $Info

    return $result.ToUpper()
}
