<#
.SYNOPSIS
Tests forest domain controllers and selects a preferred controller per domain.

.FUNCTIONALITY
Checks controller reachability and LDAP availability, then caches the preferred DCs.
#>
function Set-BestDomainController {

    ################################################################################
    #####                                                                      ##### 
    ##### Get best DC based on LDAP port availability, PDC role & RODC status  #####                      
    #####                                                                      #####
    ################################################################################

    [CmdletBinding()]
    param(
        [int]$ThrottleLimit = 20,
        [int]$TimeoutMs = 1500
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $forest = Get-ADForest
    $rootDomain = $forest.RootDomain

    $allDCs = foreach ($domain in $forest.Domains) {
        try {
            $domainInfo = Get-ADDomain -Server $domain
            $pdcFQDN = $domainInfo.PDCEmulator

            Get-ADDomainController -Filter * -Server $domain |
            ForEach-Object {

                $fqdn = if ($_.HostName) {
                    $_.HostName
                }
                else {
                    "$($_.Name).$($_.Domain)"
                }

                [PSCustomObject]@{
                    Domain       = $_.Domain
                    DC_Name      = $_.Name
                    FQDN         = $fqdn
                    IPv4         = $_.IPv4Address
                    Site         = $_.Site
                    IsPDC        = ($fqdn -eq $pdcFQDN)
                    IsRootDomain = ($_.Domain -eq $rootDomain)
                    IsRODC       = $_.IsReadOnly
                    OS           = $_.OperatingSystem
                }
            }
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
    }

    $total = $allDCs.Count

   

    Write-log -message "    >> Found $total Domain Controllers."

    $job = $allDCs | ForEach-Object -Parallel {

        $dcTarget = if ($_.IPv4) { $_.IPv4 } else { $_.FQDN }
        $ping = Test-Connection -ComputerName $dcTarget -Count 1 -Quiet -ErrorAction SilentlyContinue
        $ldapReachable = $false

        if ($ping) {
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $iar = $tcp.BeginConnect($dcTarget, 389, $null, $null)
                $wait = $iar.AsyncWaitHandle.WaitOne($using:TimeoutMs, $false)

                if ($wait -and $tcp.Connected) {
                    $ldapReachable = $true
                }

                $tcp.Close()
            }
            catch {}
        }

        [PSCustomObject]@{
            Domain          = $_.Domain
            DC_Name         = $_.DC_Name
            FQDN            = $_.FQDN
            Site            = $_.Site
            Root_Domain     = $_.IsRootDomain
            PDC_Emulator    = $_.IsPDC
            RODC            = $_.IsRODC
            Online          = $ping
            LDAP_389_Open   = $ldapReachable
            operatingSystem = $_.OS 
        }

    } -ThrottleLimit $ThrottleLimit -AsJob

    $results = @()

    while ($job.State -eq "Running") {

        $results = Receive-Job $job -Keep
        $done = $results.Count

        $percent = [math]::Round(($done / $total) * 100, 2)

        Write-Progress `
            -Activity "Checking Domain Controllers" `
            -Status "$done of $total tested" `
            -PercentComplete $percent

        Start-Sleep -Milliseconds 200
    }

    $results = Receive-Job $job
    Remove-Job $job -Force

    Write-Progress -Activity "Checking Domain Controllers" -Completed

    $4logfile = $results | Sort-Object Domain, DC_Name | Format-Table -AutoSize | Out-String
    Write-log -Message "    >> Domain Controller Health Overview: $4logfile"


    $Script:AllDCs = $results 

    $bestdcs = $results |
    Where-Object LDAP_389_Open |
    Sort-Object Domain, @{e = { -not $_.PDC_Emulator } }, @{e = { $_.RODC } } |
    Group-Object Domain |
    ForEach-Object { $_.Group[0] }

    $bestdcs = $bestdcs |  Select-Object @{N = 'RootDomain'; E = { $_.Root_Domain } }, 
    @{N = 'Domain'; E = { $_.Domain } }, @{N = 'DC'; E = { $_.DC_Name } }, RODC,
    @{N = 'PDC'; E = { $_.PDC_Emulator } }, Site, Online, 
    @{N = 'Open LDAP Port'; E = { $_.LDAP_389_Open } }, FQDN | Sort-Object RootDomain, FQDN -Descending

    $logfile = $bestdcs | Format-Table -AutoSize | Out-String
    Write-log -Message "    >> Best Domain Controller per Domain to use: $logfile"

    $bestdcs | ForEach-Object {
        $Script:BestDCs[$_.Domain] = $_.FQDN
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
    return $Script:BestDCs
}