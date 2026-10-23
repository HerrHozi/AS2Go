function Get-OSBuild {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the OS build, e.g. 22621                                      #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $computer)

    $Info = Measure-FunctionRuntime -Begin

    try {

        $property = Get-ADComputer -Identity  $computer -Properties name, operatingSystem, operatingSystemVersion -ErrorAction Stop
        if ($property.operatingSystemVersion -match '\((\d+)\)') {
            $result = $matches[1]
        }
    }
    catch {
        $result = "00000"
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }


    #https://learn.microsoft.com/de-de/windows/release-health/windows11-release-information

    Write-Log -Message "    >> using $result"
    Measure-FunctionRuntime -End -Details $Info

    return $result
}
