<#
.SYNOPSIS
Requests a reboot or shutdown of reachable configured Domain Controllers.

.DESCRIPTION
Prompts for reboot, shutdown, or skip. Unattended runs default to reboot.
The selected action is scheduled for reachable configured Domain Controllers, excluding the local computer.
Unreachable targets are reported.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Requests a reboot or shutdown for reachable configured Domain Controllers after the configured delay.
Prompts for the action, defaults to reboot when unattended, skips the local computer, and reports unreachable targets.
#>
function Invoke-Shutdown {

    $Info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -M "Trigger coordinated reboot or shutdown across accessible Domain Controllers"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $UseCase = Get-ASConfig -Setting "usecase"

    $comment = "$UseCase | Your network was hacked. All Domain Controllers will be rebooted in $Script:ASTime2Reboot seconds!!"
    Write-AS2GoOutput -Type Command "  [>] shutdown /r /f /t $Script:ASTime2Reboot /c $comment"
    
    If (-not $UnAttended) {
        
        $options = @(
            [pscustomobject] @{
                Label = "&Reboot"
                Help  = "Restart reachable Domain Controllers after the configured delay."
                Value = "Reboot"
            },
            [pscustomobject] @{
                Label = "Shut&down"
                Help  = "Shut down reachable Domain Controllers after the configured delay."
                Value = "Shutdown"
            },
            [pscustomobject] @{
                Label = "&Skip"
                Help  = "Skip the power action."
                Value = "Skip"
            }
        )
        
        $answer = Show-DecisionPrompt -Message "Choose an action." -Options $options -Default 0 -Title "Machine Power Action"

        If ($answer -eq "Skip") {
            Measure-FunctionRuntime -End -Details $Info
            Return
        }
  
    
    }
    else {
        $answer = "Reboot"
    }

    $actionVerb = if ($answer -eq "Reboot") { "reboot" } else { "shut down" }
    $actionSwitch = if ($answer -eq "Reboot") { "/r" } else { "/s" }
    $comment = "$UseCase | Your network was hacked. `nAll Domain Controllers will be $actionVerb in $Script:ASTime2Reboot seconds!!"
    #Write-AS2GoOutput -Type Command "  [>] shutdown $actionSwitch /f /t $Script:ASTime2Reboot /c $comment"

    $Script:AllDCs | Select-Object Online, Root_Domain, FQDN, RODC, OperatingSystem | format-table

   # pause

    foreach ($computer in $Script:AllDCs) {
        $remotemachine = $computer.FQDN
        $os = $computer.operatingSystem

        # check if the computer is online
        IF (Test-Connection -BufferSize 32 -Count 1 -ComputerName $remotemachine -Quiet) {

            If ($env:COMPUTERNAME -ne $computer.name) {
                If ($os -like 'Windows 1*') {
                    # only for Windows 10 machines
                    Write-AS2GoOutput -Type Bullet -Message "Try to $actionVerb Windows PC     - $remotemachine"
                    net use \\$remotemachine\ipc$
                    #shutdown /r /f /c $comment /t $Script:ASTime2Reboot /m \\$remotemachine
                }
                elseif ($os -like 'Windows 7*') {
                    Write-AS2GoOutput -Type Bullet -Message "Try to $actionVerb Windows PC     - $remotemachine"
                    #shutdown /r /f /c $comment /t $Script:ASTime2Reboot /m \\$remotemachine
                }
                else {
                    Write-AS2GoOutput -Type Bullet -Message "Try to $actionVerb Windows Server - $remotemachine"
                    #shutdown /r /f /c $comment /t $Script:ASTime2Reboot /m \\$remotemachine
                }
        
                If ($answer -eq "Reboot") {
                    & shutdown /r /f /c "$comment" /t $Script:ASTime2Reboot /m \\$remotemachine
                }
                else {
                    & shutdown /s /f /c "$comment" /t $Script:ASTime2Reboot /m \\$remotemachine
                }
                
                
            }
        } #end if Test-Connection
        Else {
            Write-AS2GoOutput -Type Warning -Message "Remote machine $remotemachine is down!"
        } 

    } 


    If (-not $UnAttended) { pause }
    Measure-FunctionRuntime -End -Details $Info
}