function Stop-AS2GoDemo {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [string]$NextStepReboot = $Script:No
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If (-not $SkipClearHost) { Clear-Host }

    $closing = "DONE!"

    Invoke-Output -Type Success -Message $closing

    Update-WindowTitle -NewTitle $closing

    $StartDate = Get-ASConfig -Setting "LastStart" 
    $EndDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
    $duration = NEW-TIMESPAN -Start $StartDate -End $EndDate
    Write-host "finished after $duration [h]"

    Set-ASConfig -Setting "LastStage" -Value $Script:Phase50
    Set-ASConfig -Setting "LastFinished" -Value  $enddate
    Set-ASConfig -Setting "LastDuration" -Value "$duration [h]"

    Write-Log -Message "Start Time: $StartDate"
    Write-Log -Message "End Time  : $EndDate"
    Write-Log -Message "Total Time: $duration"

    # clean-up AS2Go Folder
    Clear-ExfiltrationFolder
    
    if (Test-Path $Script:ASModuleLog) {
        #Invoke-Item $Script:ASModuleLog
    }
        
    If (-not $SkipImages) { 
        #Show-Phases -Phase "phase_020.html" 
    }

    If ($NextStepReboot -ne $Script:Yes) {
        return
    }

    Write-Log -Message "    >> using "
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
