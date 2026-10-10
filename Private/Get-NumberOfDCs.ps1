<#
.SYNOPSIS
Counts domain controllers in each forest domain.

.DESCRIPTION
Counts read-write and read-only domain controllers for every forest domain and stores the
totals for later configuration steps.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Stores the read-write and read-only controller totals for every domain.
#>
function Get-NumberofDCs {

    ################################################################################
    #####                                                                      ##### 
    #####    Get Number of RWDC & RODC per Domain                              #####                               
    #####                                                                      #####
    ################################################################################

    Param([string] $param1, [string] $param2)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################


    $script:ErrorForestInfo = $null

    $forest = Get-ADForest

    foreach ($domain in $forest.Domains) {

        # Immer Array erzwingen
        try {
            $dcs = @(Get-ADDomainController -Filter * -Server $domain)
            $rw = @($dcs | Where-Object { -not $_.IsReadOnly }).Count
            $ro = @($dcs | Where-Object { $_.IsReadOnly }).Count
            $total = $dcs.Count
         
        }
        catch {

            $script:ErrorForestInfo += "`n  Unable to retrieve DCs for domain '$domain'. "
            $rw = "n/a"
            $ro = "n/a"
            $total = "n/a"
        }

        $Script:DCsPerDomain[$domain] = @{
            RWDC  = $rw
            RODC  = $ro
            Total = $total 
        }
    }

    $logfile = $Script:DCsPerDomain | Out-String
    Write-log -Message "    >> Number of DCs per Domain: $logfile"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $Script:DCsPerDomain
}