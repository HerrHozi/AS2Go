function Get-ComputerInformation {

    ################################################################################
    #####                                                                      ##### 
    #####    Get Computer Information like OS, Version & Build                                
    #####                                                                      #####
    ################################################################################


    Param(
        [string] $computer
        )

    $Info = Measure-FunctionRuntime -Begin

    $summary = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

    try {
        $computerIdentity = $computer
        $ipAddress = $null

        if ([System.Net.IPAddress]::TryParse($computer, [ref]$ipAddress)) {
            $fqdn = [System.Net.Dns]::GetHostEntry($ipAddress).HostName
            $computerIdentity = $fqdn.Split('.')[0]
        }
        else
        {
            $fqdn = [System.Net.Dns]::GetHostEntry($computer).HostName
            $computerIdentity = $fqdn.Split('.')[0]
        }

        $DNSDomain = $fqdn.Substring($fqdn.IndexOf('.') + 1)

        $property = Get-ADComputer -Identity $computerIdentity -Properties SamAccountName, operatingSystem, operatingSystemVersion -Server $DNSDomain -ErrorAction Stop
    
        $Name = $property.SamAccountName.PadRight(16, [char]32)
        $prefix = $property.operatingSystem.PadRight(33, [char]32)
        $suffix = $property.operatingSystemVersion
    
        $summary = "$Name | $prefix | $suffix"
    }
    catch {
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }
    
    Write-Log -Message "    >> Computer Info $summary"

    Measure-FunctionRuntime -End -Details $Info 

    return $summary
}
