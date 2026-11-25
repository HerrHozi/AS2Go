<#
.SYNOPSIS
Configures DNS zone transfers for AS2Go training.

.DESCRIPTION
Reviews primary DNS zones and previews the proposed transfer setting before applying changes.
It can allow transfers to any server for the lab's MDI detection scenario.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Reviews primary zones, previews changes, and can allow transfers to any server.
#>
function Set-AS2GoDnsZoneConfiguration {

    ################################################################################
    #####                                                                      ##### 
    #####   Update DNS Setting 'Zone Transfer' to 'TransferAnyServer'          #####                                
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin
    If (-not $SkipClearHost) { Clear-Host }
    $dnsroot = (Get-ADDomain).dnsroot
    Write-AS2GoOutput -Type Header -Message "Update DNS Setting 'Zone Transfer' to 'TransferAnyServer'"
    Write-AS2GoOutput -Type Textmaker -Message "Handle Primary Forward Lookup Zones for " -tm $dnsroot
   
    write-host "Currently configured Primary Zones:"

    Get-DnsServerZone -ComputerName $script:logonserver | 
    Where-Object { $_.ZoneType -eq 'Primary' -and $_.ZoneName -notmatch 'TrustAnchors' }  | 
    Select-Object ZoneType, ZoneName, SecureSecondaries, IsReverseLookupZone | Sort-Object IsReverseLookupZone, ZoneName | Out-Host
    
    Write-AS2GoOutput -Type  Info -Message "The following zones will be updated to 'TransferAnyServer':"

    Get-DnsServerZone -ComputerName $script:logonserver |
    Where-Object { $_.ZoneName -match (Get-ADForest).RootDomain } |
    Set-DnsServerPrimaryZone -ComputerName $script:logonserver -SecureSecondaries TransferAnyServer -WhatIf
    
    $question = "Would you like to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $Script:Yes

    If ($answer -eq $Script:Yes) {
        Get-DnsServerZone -ComputerName $script:logonserver | 
        Where-Object { $_.ZoneName -match (Get-ADForest).RootDomain }  | 
        Set-DnsServerPrimaryZone -ComputerName $script:logonserver -SecureSecondaries TransferAnyServer

        write-host "`n`nNewly configured Primary Zones:"
        Get-DnsServerZone -ComputerName $script:logonserver | 
        Where-Object { $_.ZoneType -eq 'Primary' -and $_.ZoneName -notmatch 'TrustAnchors' }  | 
        Select-Object ZoneType, ZoneName, SecureSecondaries, IsReverseLookupZone | Sort-Object IsReverseLookupZone, ZoneName | Out-Host

        $logfile = Get-DnsServerZone -ComputerName $script:logonserver | 
        Where-Object { $_.ZoneType -eq 'Primary' -and $_.ZoneName -notmatch 'TrustAnchors' }  | 
        Select-Object ZoneType, ZoneName, SecureSecondaries, IsReverseLookupZone | Sort-Object IsReverseLookupZone, ZoneName | Format-Table -AutoSize | Out-String
        Write-Log -Message "    Newly configured Primary Zones : $logfile"

    }
    else {
        Write-log -Message "    Skipped Function ###"
    }
    Write-AS2GoOutput -Type  Success -Message "Finished updating DNS Zone Settings!"

    Measure-FunctionRuntime -End -Details $Info
}