function Get-DirContent {
    param (
        [string] $Path,
        [Switch] $SkipCommand
    )

    $Info = Measure-FunctionRuntime -Begin
    
    If (-not $SkipCommand) {
  
        Write-AS2GoOutput -Type Command -Message "Next Command: " -NoNewline
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
            Write-AS2GoOutput -Type  Success -M "Accessed path $Path successfully!"
        }
        Catch {
            if ($attempt -lt $maxAttempts) {
                Write-Log -Message "    Attempt $attempt failed for path $Path. Retrying in 2 seconds..."
                Start-Sleep -Seconds 2
            }
            else {
                Write-AS2GoOutput -Type  Error -M "No access to path $Path!"
            }
        }
    }
  
    Measure-FunctionRuntime -End -Details $Info
}
