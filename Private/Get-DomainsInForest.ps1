function Get-DomainsInForest {

    ################################################################################
    #####                                                                      ##### 
    #####  Get the type of each domain Root [Forest], Child , Root [Tree]      #####                        
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

$ForestDomains = Get-ADForest | Select-Object -ExpandProperty Domains | ForEach-Object {
    $Domain = Get-ADDomain -Identity $_ -Server $_

    [PSCustomObject]@{
        FQDN              = $Domain.DNSRoot
        NetBIOSName       = $Domain.NetBIOSName
        DomainSID         = $Domain.DomainSID.Value
        DistinguishedName = $Domain.DistinguishedName
    }
}

$4logfile = $ForestDomains | Format-Table -AutoSize | out-string
    Write-Log -Message "    >> Found the following domains in the forest: $4logfile"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $ForestDomains
}
