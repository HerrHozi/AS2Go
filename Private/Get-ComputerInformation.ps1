function Get-ComputerInformation {

    ################################################################################
    #####                                                                      ##### 
    #####    Get Computer Information like OS, Version & Build                                
    #####                                                                      #####
    ################################################################################


    Param([string] $computer)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    $summary = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

    try {
        $property = Get-ADComputer -Identity $computer -Properties name, operatingSystem, operatingSystemVersion -ErrorAction Stop
    
        $Name = $property.name.PadRight(16, [char]32)
        $prefix = $property.operatingSystem.PadRight(33, [char]32)
        $suffix = $property.operatingSystemVersion
    
        $summary = "$Name | $prefix | $suffix"
    }
    catch {
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }
    
    Write-Log -Message "    >> Computer Info $summary"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $summary
}
