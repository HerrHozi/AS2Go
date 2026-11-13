function Get-LocalComputerInformation {
    $Info = Measure-FunctionRuntime -Begin

    try {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $registry = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -Property TotalPhysicalMemory -ErrorAction Stop
        $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

        $osBuild = $registry.CurrentBuildNumber
        if ([string]::IsNullOrWhiteSpace($osBuild)) {
            $osBuild = $registry.CurrentBuild
        }

        $version = $registry.DisplayVersion
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = $registry.ReleaseId
        }
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = $registry.CurrentVersion
        }

        $information = [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            OS           = [string]$os
            OSBuild      = [int]$osBuild
            Version      = [string]$version
            Memory       = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        }

        Write-Log -Message "    >> Local computer: $($information.OS), version $($information.Version), build $($information.OSBuild), $($information.Memory) GB RAM"
        return $information
    }
    finally {
        Measure-FunctionRuntime -End -Details $Info
    }
}