<#
.SYNOPSIS
Configures DNS zone transfers for AS2Go training.

.FUNCTIONALITY
Reviews primary zones, previews changes, and can allow transfers to any server.
#>
function Invoke-DNSZoneUpdate {

    ################################################################################
    #####                                                                      ##### 
    #####   Update DNS Setting 'Zone Transfer' to 'TransferAnyServer'          #####                                
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    If (-not $SkipClearHost) { Clear-Host }
    $dnsroot = (Get-ADDomain).dnsroot
    Invoke-Output -Type Header -Message "Update DNS Setting 'Zone Transfer' to 'TransferAnyServer'"
    Invoke-output -Type Textmaker -Message "Handle Primary Forward Lookup Zones for " -tm $dnsroot
   
    write-host "Currently configured Primary Zones:"

    Get-DnsServerZone -ComputerName $script:logonserver | 
    Where-Object { $_.ZoneType -eq 'Primary' -and $_.ZoneName -notmatch 'TrustAnchors' }  | 
    Select-Object ZoneType, ZoneName, SecureSecondaries, IsReverseLookupZone | Sort-Object IsReverseLookupZone, ZoneName | Out-Host
    
    Invoke-Output -T Info -Message "The following zones will be updated to 'TransferAnyServer':"

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
    Invoke-Output -T Success -Message "Finished updating DNS Zone Settings!"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}