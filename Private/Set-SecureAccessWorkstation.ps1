<#
.SYNOPSIS
Selects or keeps the lab's Secure Access Workstation (SAW).

.DESCRIPTION
Stores the selected workstation's host name in the AS2Go configuration for use by lab scenarios.
The workstation can be selected from Active Directory or entered manually.

.FUNCTIONALITY
Selects and stores the computer used as the Secure Access Workstation.

.COMPONENT
Category: Main Function
#>
function Set-SecureAccessWorkstation {

    $Info = Measure-FunctionRuntime -Begin
    Write-AS2GoOutput -Type Header -Message "Define a Secure Access Workstation"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $previousSAW = Get-ASConfig -Setting "AS2GoSAW"

    if (-not [string]::IsNullOrWhiteSpace([string]$previousSAW)) {
        $message = "Use the current Secure Access Workstation ($previousSAW) or select a new one:"
        $helpPrevious = "Keep the workstation from the previous configuration."
        Write-AS2GoOutput -Type TextMaker -Message "Current Secure Access Workstation:" -Tm $previousSAW
        $options = @(
            [pscustomobject]@{ Label = "&Previous Secure Access Workstation"; Help = $helpPrevious; Value = "Previous" },
            [pscustomobject]@{ Label = "Select &new Secure Access Workstation"; Help = "Choose a computer to use as the Secure Access Workstation."; Value = "New" },
            [pscustomobject]@{ Label = "&Type new Secure Access Workstation"; Help = "Manually enter the host name of the Secure Access Workstation."; Value = "Type" },
            [pscustomobject]@{ Label = "&Skip"; Help = "Skip selecting a Secure Access Workstation."; Value = "Skip" }
        )
    }
    else {
        $message = "Select a computer to use as the Secure Access Workstation:"
        $options = @(
            [pscustomobject]@{ Label = "Select &new Secure Access Workstation"; Help = "Choose a computer to use as the Secure Access Workstation."; Value = "New" },
            [pscustomobject]@{ Label = "&Type new Secure Access Workstation"; Help = "Manually enter the host name of the Secure Access Workstation."; Value = "Type" },
            [pscustomobject]@{ Label = "&Skip"; Help = "Skip selecting a Secure Access Workstation."; Value = "Skip" }
        )
    }

    $Title = "Secure Access Workstation - Select Computer"
    $Decision = Show-DecisionPrompt -Message $message -Options $options -Default 0 -Title $Title
    $sawComputerName = $null

    if ($Decision -eq "New") {
        $computerDN = Select-ADObject -Title $Title -IncludeComputers

        if (-not [string]::IsNullOrWhiteSpace([string]$computerDN)) {
            try {
                $computer = [ADSI]"LDAP://$computerDN"
                $computerName = [string]$computer.Properties['dNSHostName'][0]

                if ([string]::IsNullOrWhiteSpace($computerName)) {
                    $computerName = [string]$computer.Properties['name'][0]
                }

                if ([string]::IsNullOrWhiteSpace($computerName)) {
                    throw "Could not read a host name for computer '$computerDN'."
                }

                Set-ASConfig -Setting "AS2GoSAW" -Value $computerName
                $sawComputerName = $computerName
                Write-AS2GoOutput -Type TextMaker -Message "New Secure Access Workstation:" -Tm $computerName
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Could not set the Secure Access Workstation: $_"
            }
        }
    }
    elseif ($Decision -eq "Type") {
        $computerName = Write-AS2GoOutput -Type Input -Message "Enter the host name of the Secure Access Workstation"

        if ([string]::IsNullOrWhiteSpace([string]$computerName)) {
            Write-AS2GoOutput -Type Warning -Message "No host name entered. The Secure Access Workstation configuration was not changed."
        }
        else {
            $computerName = $computerName.Trim()
            Set-ASConfig -Setting "AS2GoSAW" -Value $computerName
            $sawComputerName = $computerName
            Write-AS2GoOutput -Type TextMaker -Message "New Secure Access Workstation:" -Tm $computerName
        }
    }
    elseif ($Decision -eq "Previous") {
        $sawComputerName = $previousSAW
        Write-AS2GoOutput -Type Info -Message "Keep previous Secure Access Workstation!"
    }

    else {
        return
        Write-log -Message "Skipping Secure Access Workstation selection."
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$sawComputerName)) {
        $winRMReachable = & {
            $ProgressPreference = 'SilentlyContinue'
            Test-NetConnection -ComputerName $sawComputerName -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue -ProgressAction SilentlyContinue -ErrorAction SilentlyContinue
        }

        if ($winRMReachable) {
            Write-AS2GoOutput -Type Success -Message "WinRM is reachable on $sawComputerName (TCP 5985)."
        }
        else {
            Write-AS2GoOutput -Type Warning -Message "WinRM is not reachable on $sawComputerName (TCP 5985)." -NoExtraLines

            $options = @(
                [pscustomobject]@{
                    Label = "&Yes"
                    Help  = "Enable PowerShell Remoting on $sawComputerName using DCOM."
                    Value = $Script:Yes
                },
                [pscustomobject]@{
                    Label = "&No"
                    Help  = "Skip enabling PowerShell Remoting on $sawComputerName."
                    Value = $Script:No
                }
            )
            $decision = Show-DecisionPrompt -Message "Do you want to enable PowerShell Remoting on '$sawComputerName'?" `
                -Options $options -Default 1 -Title "Enable PowerShell Remoting"

            if ($decision -eq $Script:Yes) {
                $opt = New-CimSessionOption -Protocol Dcom
                $sess = New-CimSession -ComputerName $sawComputerName -SessionOption $opt
                Invoke-CimMethod -CimSession $sess -ClassName Win32_Process -MethodName Create `
                    -Arguments @{ CommandLine = 'powershell.exe -NoProfile -Command "Enable-PSRemoting -Force"' }
            }
            else {
                Write-AS2GoOutput -Type Info -Message "Skipped enabling PowerShell Remoting on $sawComputerName."
            }

        }
    }

    Measure-FunctionRuntime -End -Details $Info
}
