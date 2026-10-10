<#
.SYNOPSIS
Resolves the current logon server to its fully qualified domain name.

.DESCRIPTION
Resolves LOGONSERVER through Active Directory and falls back to DNS when the directory lookup
does not return a result.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Resolves LOGONSERVER through Active Directory, with DNS lookup as a fallback.
#>
function Get-LogonServerFQDN {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the FQDN of the current logon server                          #####                           
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $logonServer = $env:LOGONSERVER -replace '^\\\\',''

    if (-not $logonServer) {
        throw "Unable to determine LOGONSERVER from environment."
    }

    # 2. Resolve to FQDN via AD
    try {
        $logonServer = (Get-ADDomainController -Identity $logonServer).HostName
    }
    catch {
        # 3. DNS fallback
        try {
            $logonServer = [System.Net.Dns]::GetHostEntry($logonServer).HostName
        }
        catch {
            throw "Unable to resolve FQDN for logon server '$logonServer'."
        }
    }

    Write-Log -Message "    >> found logon server FQDN: $logonServer"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $logonServer
}