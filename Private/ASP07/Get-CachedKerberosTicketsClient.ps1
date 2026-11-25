<#
.SYNOPSIS
Gets the client name from the current user's cached Kerberos tickets.

.DESCRIPTION
Runs klist locally and returns the client name in uppercase, or a no-tickets
message when no cached tickets are listed.

.OUTPUTS
System.String

.EXAMPLE
Get-CachedKerberosTicketsClient
Returns the cached Kerberos ticket client name or a no-tickets message.

.FUNCTIONALITY
Reports the client associated with cached Kerberos tickets.
#>
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
    If ($results.count -ge 5) {
        $result = $results[5].Split(":")[-1].trim()
    }
    else {
        $result = "Cached Tickets: (0)"
    }

    Write-Log -Message "    >> found $user - $foundUser!"
    Measure-FunctionRuntime -End -Details $Info

    return $result.ToUpper()
}
