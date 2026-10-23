function Get-DirContent {
    param (
        [string] $Path,
        [Switch] $SkipCommand
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################
    
    If (-not $SkipCommand) {
  
        Invoke-Output -Type Command -Message "Next Command: " -NoNewline
        $command = "Get-ChildItem -Path $Path"
        Write-Syntax -Code $command
    
    }


    $maxAttempts = 3
    $attempt = 0
    $isSuccess = $false

    while (-not $isSuccess -and $attempt -lt $maxAttempts) {
        $attempt++
        Try {
            Get-ChildItem -Path $Path -ErrorAction Stop | Out-Host
            $isSuccess = $true
            Invoke-Output -Type  Success -M "Accessed path $Path successfully!"
        }
        Catch {
            if ($attempt -lt $maxAttempts) {
                Write-Log -Message "    Attempt $attempt failed for path $Path. Retrying in 2 seconds..."
                Start-Sleep -Seconds 2
            }
            else {
                Invoke-Output -Type  Error -M "No access to path $Path!"
            }
        }
    }
  
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
