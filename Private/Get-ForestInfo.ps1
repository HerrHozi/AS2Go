function Get-ForestInfo {

    ################################################################################
    #####                                                                      ##### 
    #####   Get the Forest and Domain Information including Priviledge Groups  #####                                 
    #####                                                                      #####
    ################################################################################


    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################


    $Script:GroupEA = @()
    $Script:GroupSA = @()
    $Script:GroupPUG = @()
    $Script:GroupDA = @()
    $Script:GroupDNSA = @()

    $Forest = Get-ADForest
    $CurrentDomain = (Get-ADDomain).DNSRoot

    $Script:AllDomainsDetails = $Forest.Domains | ForEach-Object {
        Get-DomainDetails -DomainName $_
    }

    #$Script:AllDomainsDetails | Select-Object DomainFQDN, DomainName, NetBIOSName, IsRootDomain, IsCurrentDomain, DomainMode, PdcRoleOwner, NearestRWDC, DomainSID  | Format-Table -AutoSize


    $4logfile = $Script:AllDomainsDetails | Format-Table DomainFQDN, DomainDN, DomainName, NetBIOSName, DomainSID, DomainMode, IsRootDomain, IsCurrentDomain, PdcRoleOwner, NearestRWDC, Scan | Out-String
    Write-Log -Message $4logfile

    #root domain
    $result = $Script:AllDomainsDetails | Select-Object * |  Where-Object { $_.IsRootDomain -like 'True' } 

    $Script:GroupEA += [PSCustomObject]@{
        FQDN           = $result.DomainFQDN
        Domain         = $result.NetBIOSName
        SID            = $result.DomainSID + "-519"
        SamAccountName = Get-ADGroupSamAccountNameBasedOnRID -RID "-519" -Domain $($result.DomainFQDN)
        CanonicalName  = Get-CanonicalName -SID ($result.DomainSID + "-519") -Domain $($result.DomainFQDN)
    }

    $Script:GroupSA += [PSCustomObject]@{
        FQDN           = $result.DomainFQDN
        Domain         = $result.NetBIOSName
        SID            = $result.DomainSID + "-518"
        SamAccountName = Get-ADGroupSamAccountNameBasedOnRID -RID "-518" -Domain $($result.DomainFQDN)
        CanonicalName  = Get-CanonicalName -SID ($result.DomainSID + "-519") -Domain $($result.DomainFQDN)
    }

    $CurrentDomain = $Script:AllDomainsDetails | Select-Object * |  Where-Object { $_.IsCurrentDomain -like 'True' } 

    $Script:GroupDA += [PSCustomObject]@{
        FQDN           = $CurrentDomain.DomainFQDN
        Domain         = $CurrentDomain.NetBIOSName
        SID            = $CurrentDomain.DomainSID + "-512"
        SamAccountName = Get-ADGroupSamAccountNameBasedOnRID -RID "-512" -Domain $($CurrentDomain.DomainFQDN)

        CanonicalName  = Get-CanonicalName -SID ($CurrentDomain.DomainSID + "-512") -Domain $($CurrentDomain.DomainFQDN)

    }

    $Script:GroupPUG += [PSCustomObject]@{
        FQDN           = $CurrentDomain.DomainFQDN
        Domain         = $CurrentDomain.NetBIOSName
        SID            = $CurrentDomain.DomainSID + "-525"
        SamAccountName = Get-ADGroupSamAccountNameBasedOnRID -RID "-525" -Domain $($CurrentDomain.DomainFQDN)
        CanonicalName  = Get-CanonicalName -SID ($CurrentDomain.DomainSID + "-512") -Domain $($CurrentDomain.DomainFQDN)
    }

    $DNSADMINS = Get-ADGroup -server $CurrentDomain.DomainFQDN  -filter * -Properties SamAccountName, SID  | Select-Object SamAccountName, SID |  Where-Object { $_.samaccountname -like 'DnsAdmins' }
    
    $Script:GroupDNSA += [PSCustomObject]@{
        FQDN           = $CurrentDomain.DomainFQDN 
        Domain         = $CurrentDomain.NetBIOSName
        SID            = $DNSADMINS.SID
        SamAccountName = $DNSADMINS.SamAccountName
        CanonicalName  = Get-CanonicalName -SID ($DNSADMINS.SID) -Domain $($CurrentDomain.DomainFQDN)
    }

    Invoke-Output -Type  Header -M "Priviledge Groups identified based on RID"

    $allGroups = $Script:GroupDA + $Script:GroupPUG + $Script:GroupEA + $Script:GroupSA + $Script:GroupDNSA
    $allGroups | Select-Object Domain, SamAccountName, SID, CanonicalName | Format-Table | Out-Host

    $4logfile = $allGroups | Select-Object Domain, SamAccountName, SID, CanonicalName | Format-Table | Out-String
    Write-Log -Message $4logfile
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

}

function Get-DomainDetails {

    Param([string]$DomainName)

    try {
        $DomainInfo = Get-ADDomain -Server $DomainName -ErrorAction Stop
        [PSCustomObject]@{
            DomainFQDN      = $DomainInfo.DNSRoot
            DomainDN        = $DomainInfo.DistinguishedName
            DomainName      = $DomainInfo.DNSRoot.Split('.')[0]
            NetBIOSName     = $DomainInfo.NetBIOSName
            DomainSID       = $DomainInfo.DomainSID.Value
            DomainMode      = $DomainInfo.DomainMode
            IsRootDomain    = ($DomainInfo.DNSRoot -eq $Forest.RootDomain)
            IsCurrentDomain = ($DomainInfo.DNSRoot -eq $CurrentDomain)
            PdcRoleOwner    = $DomainInfo.PDCEmulator
            NearestRWDC     = $DomainInfo.InfrastructureMaster
        }
    }
    catch {
        Invoke-Output -Type  Warning -M ("$DomainName | $_")
    }




}

function Get-CanonicalName {
    Param([string]$SID, [string]$Domain, [string]$DN)
    $CanonicalName = (Get-ADObject -Server $Domain -filter * -Properties CanonicalName, objectSid | Where-Object { $_.objectSid -like $SID }).CanonicalName
    return $CanonicalName
}

