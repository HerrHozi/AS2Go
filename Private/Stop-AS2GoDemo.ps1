<#
.SYNOPSIS
Closes the AS2Go demonstration, displays its duration, and records completion time and status in the configuration.

.FUNCTIONALITY
Closes the AS2Go demonstration, displays its duration, and records completion time and status in the configuration.
Runs the exfiltration-folder cleanup workflow before returning.
#>
function Stop-AS2GoDemo {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [string]$NextStepReboot = $Script:No
    )


    $info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Stop-AS2GoDemo"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    If (-not $SkipClearHost) { Clear-Host }

    $closing = "DONE!"

    Write-AS2GoOutput -Type Success -Message $closing

    Update-WindowTitle -NewTitle $closing

    $StartDate = Get-ASConfig -Setting "LastStart" 
    $EndDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
    $duration = NEW-TIMESPAN -Start $StartDate -End $EndDate

    Write-AS2GoOutput -Type Info -Message "finished after $duration [h]"

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
        #Show-CurrentPhase -Phase "phase_020.html" 
    }

    If ($NextStepReboot -ne $Script:Yes) {
        return
    }

    Measure-FunctionRuntime -End -details $info
}
