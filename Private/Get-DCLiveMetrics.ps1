<#
.SYNOPSIS
Measures CPU load and LDAP response time on a domain controller.

.FUNCTIONALITY
Uses remote counters and RootDSE access, then returns CPU and LDAP metrics.
#>
function Get-DCLiveMetrics {
    param([string]$Server)

    try {
        $cpu = (Get-Counter -ComputerName $Server '\Processor(_Total)\% Processor Time' -MaxSamples 1 -ErrorAction Stop).CounterSamples[0].CookedValue
        $cpu = [math]::Round($cpu, 1)
    }
    catch {
        try {
            $cpuSamples = Get-CimInstance -ClassName Win32_Processor -ComputerName $Server -OperationTimeoutSec 3 -ErrorAction Stop |
            Select-Object -ExpandProperty LoadPercentage

            if ($cpuSamples) {
                $cpu = [math]::Round((($cpuSamples | Measure-Object -Average).Average), 1)
            }
            else {
                $cpu = "n/a"
            }
        }
        catch {
            $cpu = "n/a"
        }
    }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $d = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/RootDSE")
        $null = $d.Properties["defaultNamingContext"].Value
        $sw.Stop()
        $lat = $sw.ElapsedMilliseconds
    }
    catch { $lat = "n/a" }

    [pscustomobject]@{
        CPU  = $cpu
        LDAP = $lat
    }
}