function Invoke-FakeRansomwarePopUp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourceFile,

        [string]$TargetFile = 'C:\Temp\your-files-have-been-encrypted.html'
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    try {
        $targetDrivePath = $TargetFile -replace ':', '$'
        $uncTarget = "\\$ComputerName\$targetDrivePath"
        $uncFolder = Split-Path -Path $uncTarget -Parent

        if (-not (Test-Path -Path $uncFolder)) {
            New-Item -Path $uncFolder -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path $SourceFile -Destination $uncTarget -Force

        $session = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $lines = quser 2>$null | Select-Object -Skip 1

            if (-not $lines) {
                throw "No interactive user session found."
            }

            $parsed = foreach ($line in $lines) {
                $normalized = ($line -replace '^\s*>?', '' -replace '\s{2,}', '|').Trim()
                $parts = $normalized -split '\|'

                if ($parts.Count -ge 4) {
                    [PSCustomObject]@{
                        UserName    = $parts[0].Trim()
                        SessionName = $parts[1].Trim()
                        Id          = $parts[2].Trim()
                        State       = $parts[3].Trim()
                    }
                }
            }

            $activeSession = $parsed |
            Where-Object { $_.State -eq 'Active' -and -not [string]::IsNullOrWhiteSpace($_.UserName) } |
            Select-Object -First 1

            if (-not $activeSession) {
                throw "No active interactive user session found."
            }

            $activeSession
        }

        $loggedOnUser = $session.UserName
        $taskName = "AS2Go-OpenHtmlDemo-$($session.Id)"

        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param(
                $TargetFile,
                $RunAsUser,
                $TaskName
            )

            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

            $action = New-ScheduledTaskAction -Execute 'explorer.exe' -Argument "`"$TargetFile`""
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30)
            $principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType Interactive

            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
            Start-ScheduledTask -TaskName $TaskName
        } -ArgumentList $TargetFile, $loggedOnUser, $taskName

        $temp = [PSCustomObject]@{
            ComputerName = $ComputerName
            UserName     = $loggedOnUser
            SessionId    = $session.Id
            TargetFile   = $TargetFile
            TaskName     = $taskName
            Status       = 'Started'
        }
    
        Invoke-Output -Type Success -Message "Encrypted - Go to Domain Controller --> $affectedDC" -noExtraLines  
    }
    catch {
        Invoke-Output -Type Info -Message "$($_.Exception.Message) But encrypted --> $affectedDC" -noExtraLines
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}