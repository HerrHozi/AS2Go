function Get-DomainsInForest {

    ################################################################################
    #####                                                                      ##### 
    #####  Get the type of each domain Root [Forest], Child , Root [Tree]      #####                        
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

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

    Measure-FunctionRuntime -End -Details $Info

    return $ForestDomains
}
