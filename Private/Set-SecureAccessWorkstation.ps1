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
    Invoke-Output -Type Header -Message "Define a Secure Access Workstation"
    Invoke-Output -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $previousSAW = Get-ASConfig -Setting "mySAW"

    if (-not [string]::IsNullOrWhiteSpace([string]$previousSAW)) {
        $message = "Use the current Secure Access Workstation ($previousSAW) or select a new one:"
        $helpPrevious = "Keep the workstation from the previous configuration."
        Invoke-Output -Type TextMaker -Message "Current Secure Access Workstation:" -Tm $previousSAW
        $options = @(
            [pscustomobject]@{ Label = "&Previous Secure Access Workstation"; Help = $helpPrevious; Value = "Previous" },
            [pscustomobject]@{ Label = "Select &new Secure Access Workstation"; Help = "Choose a computer to use as the Secure Access Workstation."; Value = "New" },
            [pscustomobject]@{ Label = "&Type new Secure Access Workstation"; Help = "Manually enter the host name of the Secure Access Workstation."; Value = "Type" }
        )
    }
    else {
        $message = "Select a computer to use as the Secure Access Workstation:"
        $options = @(
            [pscustomobject]@{ Label = "Select Secure Access Workstation"; Help = "Choose a computer to use as the Secure Access Workstation."; Value = "New" },
            [pscustomobject]@{ Label = "&Type new Secure Access Workstation"; Help = "Manually enter the host name of the Secure Access Workstation."; Value = "Type" }
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

                Set-ASConfig -Setting "mySAW" -Value $computerName
                $sawComputerName = $computerName
                Invoke-Output -Type TextMaker -Message "New Secure Access Workstation:" -Tm $computerName
            }
            catch {
                Invoke-Output -Type Warning -Message "Could not set the Secure Access Workstation: $_"
            }
        }
    }
    elseif ($Decision -eq "Type") {
        $computerName = Invoke-Output -Type Input -Message "Enter the host name of the Secure Access Workstation"

        if ([string]::IsNullOrWhiteSpace([string]$computerName)) {
            Invoke-Output -Type Warning -Message "No host name entered. The Secure Access Workstation configuration was not changed."
        }
        else {
            $computerName = $computerName.Trim()
            Set-ASConfig -Setting "mySAW" -Value $computerName
            $sawComputerName = $computerName
            Invoke-Output -Type TextMaker -Message "New Secure Access Workstation:" -Tm $computerName
        }
    }
    else {
        $sawComputerName = $previousSAW
        Invoke-Output -Type Info -Message "Keep previous Secure Access Workstation!"
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$sawComputerName)) {
        $winRMReachable = Test-NetConnection -ComputerName $sawComputerName -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

        if ($winRMReachable) {
            Invoke-Output -Type Success -Message "WinRM is reachable on $sawComputerName (TCP 5985)."
        }
        else {
            Invoke-Output -Type Warning -Message "WinRM is not reachable on $sawComputerName (TCP 5985)."
        }
    }

    Measure-FunctionRuntime -End -Details $Info
}
