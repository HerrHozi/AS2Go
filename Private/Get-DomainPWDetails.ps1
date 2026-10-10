<#
.SYNOPSIS
Collects domain details and the default password policy.

.FUNCTIONALITY
Returns domain metadata, password settings, machine-account quota, and enabled-user count.
#>
function Get-DomainPWDetails {

    Param([string]$DomainName)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################


    try {
        $DomainInfo = Get-ADDomain -Server $DomainName
        $DomainObject = Get-ADObject -Identity $DomainInfo.DistinguishedName -Properties 'ms-DS-MachineAccountQuota' -Server $DomainName
        $PWPOlicy = Get-ADDefaultDomainPasswordPolicy -Server $DomainName

        [PSCustomObject]@{
            DomainType                  = $Script:DoaminTypes[$DomainInfo.DNSRoot]
            DomainFQDN                  = $DomainInfo.DNSRoot
            DomainDN                    = $DomainInfo.DistinguishedName
            DomainName                  = $DomainInfo.DNSRoot.Split('.')[0]
            NetBIOSName                 = $DomainInfo.NetBIOSName
            DomainSID                   = $DomainInfo.DomainSID.Value
            DomainMode                  = $DomainInfo.DomainMode
            MachineAccountQuota         = $DomainObject.'ms-DS-MachineAccountQuota'
            IsRootDomain                = ($DomainInfo.DNSRoot -eq $Forest.RootDomain)
            IsCurrentDomain             = If ($DomainInfo.DNSRoot -eq $CurrentDomain) { "Yes" } else { "" }
            PdcRoleOwner                = $DomainInfo.PDCEmulator
            NearestRWDC                 = $DomainInfo.InfrastructureMaster
            ComplexityEnabled           = $PWPOlicy.ComplexityEnabled
            MinPasswordLength           = $PWPOlicy.MinPasswordLength
            LockoutThreshold            = $PWPOlicy.LockoutThreshold
            LockoutDuration             = $PWPOlicy.LockoutDuration
            LockoutObservationWindow    = $PWPOlicy.LockoutObservationWindow
            MaxPasswordAge              = $PWPOlicy.MaxPasswordAge
            MinPasswordAge              = $PWPOlicy.MinPasswordAge
            ReversibleEncryptionEnabled = $PWPOlicy.ReversibleEncryptionEnabled
            EnabledUser                 = Get-ADUser -Filter 'Enabled -eq $true' -Server $($DomainInfo.DNSRoot) -SearchBase $($DomainInfo.DistinguishedName) | Measure-Object | Select-Object -ExpandProperty Count
        }
    }
    catch {
        
    }


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}