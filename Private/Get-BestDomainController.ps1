<#
.SYNOPSIS
Returns the preferred domain controller for a domain.

.DESCRIPTION
Accepts a domain name or distinguished name, resolves its domain, and returns the cached
preferred domain controller.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Resolves a domain name or distinguished name through the configured controller map.
#>
function Get-BestDomainController {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the best DC based on the target domain                        #####                                
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(Mandatory)]
        [string] $Domain
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ($Domain -match 'OU=|CN=|DC=' ) {
        $result = Convert-FromDNToCN -DistinguishedName $Domain
        $fqdn = $result.Split('/')[0]
    }
    else {
        $fqdn = $Domain.Split('/')[0]
    }
    
    
    If ($Script:BestDCs.count -eq 0) {
        $Script:BestDCs = Set-BestDomainController
    }

    $bestdc = $Script:BestDCs[$fqdn]


    Write-Log -Message "    >> Best DC for '$domain' is '$bestdc'!"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $bestdc
}