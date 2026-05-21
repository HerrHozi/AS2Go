function Get-OSBuild {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the OS build, e.g. 22621                                      #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $computer)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

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
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result
}
