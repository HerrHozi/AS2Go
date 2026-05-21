function Get-OSVersion {

    ################################################################################
    #####                                                                      ##### 
    #####    Description   Get-OSVersion                                       #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $computer)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################




    try {
        $property = Get-ADComputer -Identity  $computer -Properties name, operatingSystem, operatingSystemVersion    -ErrorAction Stop

if ($property.operatingSystemVersion -match '\((\d+)\)') {
    $value = "V" + $matches[1]
}

    }
    catch {
        $value = "V00000"
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }

    #https://learn.microsoft.com/de-de/windows/release-health/windows11-release-information

    $Script:WinVersion = @{

        #Win 11
V26100 = "24H2"     # Windows 11 2024 Update
V22631 = "23H2"     # Windows 11 2023 Update
V22621 = "22H2"     # Windows 11 2022 Update
V22000 = "21H2"     # Original Release (2021)

        #Win 10
        V19045 = "22H2"
        V19044 = "21H2"
        V19043 = "21H1"
        V19042 = "20H2"
        V19041 = "2004"
        V18363 = "1909"
        V18362 = "1903"
        V17763 = "1809"
        V17134 = "1803"
        V16299 = "1709"
        V15063 = "1703"
        V14393 = "1607"
        V10586 = "1511"
        V10240 = "1507"
        V00000 = "0000"



        # Windows Server 2025 (LTSC)
#V26100 = "24H2"

# Windows Server 2022 (LTSC)
V20348 = "21H2"

# Windows Server 2022 (AC)
V25398 = "23H2"

# Windows Server 2019 (LTSC)
#V17763 = "2019 / 1809"

# Windows Server (SAC releases)
#V18362 = "1903 (SAC)"
#V18363 = "1909 (SAC)"
#V19041 = "2004 (SAC)"
#V19042 = "20H2 (SAC)"

    }
    

    Write-Log -Message "    >> using $value - $($Script:WinVersion.$value)"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $Script:WinVersion.$value
}
