<#
.SYNOPSIS
Classifies the domains in an Active Directory forest.

.DESCRIPTION
Labels each forest domain as the root domain, a child domain, or the root of a separate tree.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Labels each domain as a forest root, child domain, or separate tree root.
#>
function Get-DomainType {

    ################################################################################
    #####                                                                      ##### 
    #####  Get the type of each domain Root [Forest], Child , Root [Tree]      #####                        
    #####                                                                      #####
    ################################################################################

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string] $ForestDnsName
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    # Ensure AD module
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Invoke-Output -Type  Error -M "The 'ActiveDirectory' PowerShell module is not installed."
        return
    }

    Import-Module ActiveDirectory -ErrorAction Stop
    
    try {
        if ($ForestDnsName) {
            $forest = Get-ADForest -Identity $ForestDnsName -ErrorAction Stop
        }
        else {
            $forest = Get-ADForest -ErrorAction Stop
        }
    }
    catch {
        Throw "Unable to retrieve forest info: $($_.Exception.Message)"
    }
    
    $forestRoot = $forest.RootDomain
    $domains = $forest.Domains
    
    $result = @{}   # regular hashtable
    
    foreach ($d in $domains) {
        # Attempt to get authoritative DNSRoot for the domain
        try {
            $domObj = Get-ADDomain -Identity $d -Server $d -ErrorAction Stop
            $dns = $domObj.DNSRoot
        }
        catch {
            # fallback: use the returned domain name if Get-ADDomain fails
            $dns = $d
        }
    
        if ($dns -ieq $forestRoot) {
            $type = 'Root [Forest]'
        }
        elseif ($dns -like "*.$forestRoot") {
            $type = 'Child Domain'
        }
        else {
            $type = 'Root [Tree]'
        }

        $result[$dns] = $type
    }
    
       
    $4logfile = $result.GetEnumerator() | Format-Table -AutoSize | Out-String
    Write-Log -Message "    >> Filled hashtable with Domain Types: $4logfile"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result
}
