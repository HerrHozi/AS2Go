<#
.SYNOPSIS
Removes AS2Go demo accounts and/or the named demo principal set.

.DESCRIPTION
Discovers AS2Go demo objects by the adminDescription tag written at creation
(AS2Go|Scenario|ASP00|Create) combined with their Description marker, and removes them.
-DemoUser removes the randomly generated demo users created by Invoke-DemoAccounts.
-DemoPrincipalSet removes the named lab principals and the compromised account created by
New-AS2GoDemoPrincipalSet/Add-CompromisedAccount, their Kerberoastable SPN computer, and the
local user profile left behind on the machine this function runs on.

.PARAMETER DemoUser
Removes the randomly generated demo users.

.PARAMETER DemoPrincipalSet
Removes the named lab principals, the compromised account, the SPN computer, and local profiles.

.PARAMETER Scenario
Scenario label used to match the adminDescription tag. Defaults to AS2Go.

.PARAMETER Server
Domain controller used for Active Directory operations.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Finds and removes AS2Go demo users and/or named lab principals by their creation tag,
including the SPN computer and any local user profile left on this machine.
#>
function Remove-AS2GoDemoAccounts {

    param(
        [switch] $DemoUser,
        [switch] $DemoPrincipalSet,
        [string] $Scenario = "AS2Go",
        [Parameter(Mandatory)]
        [string] $Server
    )

    $Info = Measure-FunctionRuntime -Begin

    $DomainDN = (Get-ADDomain -Server $Server).DistinguishedName
    $TagFilter = "*|$Scenario|ASP00|Create"

    if ($DemoUser) {
        Write-AS2GoOutput -Type Header -Message "Removing AS2Go Demo Users"
        try {
            $users = @(Get-ADUser -LDAPFilter "(&(adminDescription=$TagFilter)(description=AS2Go Demo User))" -SearchBase $DomainDN -Server $Server -ErrorAction Stop)
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Unable to query demo users: $_"
            $users = @()
        }

        if ($users.Count -eq 0) {
            Write-AS2GoOutput -Type Warning -Message "No tagged AS2Go demo users were found."
        }
        else {
            $Options = @(
                [pscustomobject] @{ Label = "&Yes"; Help = "Delete $($users.Count) demo user(s)."; Value = $Script:Yes },
                [pscustomobject] @{ Label = "&No"; Help = "Skip removing demo users."; Value = $Script:No }
            )
            $answer = Show-DecisionPrompt -Message "Remove $($users.Count) AS2Go demo user(s)?" -Options $Options -Default 1

            if ($answer -eq $Script:Yes) {
                foreach ($u in $users) {
                    try {
                        Remove-ADUser -Identity $u -Server $Server -Confirm:$false -ErrorAction Stop
                        Write-AS2GoOutput -Type Success -Message "Removed demo user '$($u.SamAccountName)'." -NoExtraLines
                    }
                    catch {
                        Write-AS2GoOutput -Type Warning -Message "Failed to remove '$($u.SamAccountName)': $_"
                    }
                }
            }
        }
    }

    if ($DemoPrincipalSet) {
        Write-AS2GoOutput -Type Header -Message "Removing AS2Go Demo Principal Set"

        $principalDescriptions = @('AS2Go Lab Account', 'AS2Go Dummy User')
        try {
            $principals = @(Get-ADUser -LDAPFilter "(&(adminDescription=$TagFilter)(|(description=AS2Go Lab Account)(description=AS2Go Dummy User)))" -SearchBase $DomainDN -Properties SID -Server $Server -ErrorAction Stop)
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Unable to query named lab principals: $_"
            $principals = @()
        }

        if ($principals.Count -eq 0) {
            Write-AS2GoOutput -Type Warning -Message "No tagged AS2Go named lab principals were found."
        }
        else {
            $Options = @(
                [pscustomobject] @{ Label = "&Yes"; Help = "Delete $($principals.Count) principal(s), their local profile(s) on $env:COMPUTERNAME, and the SPN computer."; Value = $Script:Yes },
                [pscustomobject] @{ Label = "&No"; Help = "Skip removing the demo principal set."; Value = $Script:No }
            )
            $answer = Show-DecisionPrompt -Message "Remove $($principals.Count) AS2Go named lab principal(s)?" -Options $Options -Default 1

            if ($answer -eq $Script:Yes) {
                foreach ($p in $principals) {
                    try {
                        $sid = $p.SID.Value
                        $profile = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$sid'" -ErrorAction SilentlyContinue
                        if ($profile) {
                            try {
                                $profile | Remove-CimInstance -ErrorAction Stop
                                Write-AS2GoOutput -Type Success -Message "Removed local profile for '$($p.SamAccountName)' on $env:COMPUTERNAME." -NoExtraLines
                            }
                            catch {
                                Write-AS2GoOutput -Type Warning -Message "Failed to remove local profile for '$($p.SamAccountName)' on $env:COMPUTERNAME`: $_"
                            }
                        }
                    }
                    catch {
                        Write-AS2GoOutput -Type Warning -Message "Failed to look up local profile for '$($p.SamAccountName)': $_"
                    }

                    try {
                        Remove-ADUser -Identity $p -Server $Server -Confirm:$false -ErrorAction Stop
                        Write-AS2GoOutput -Type Success -Message "Removed lab principal '$($p.SamAccountName)'." -NoExtraLines
                    }
                    catch {
                        Write-AS2GoOutput -Type Warning -Message "Failed to remove '$($p.SamAccountName)': $_"
                    }
                }
            }
        }

        try {
            $spnComputers = @(Get-ADComputer -LDAPFilter "(&(adminDescription=$TagFilter)(description=AS2Go Lab Computer - needed for Kerberoasting Attack))" -SearchBase $DomainDN -Server $Server -ErrorAction Stop)
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Unable to query the SPN target computer: $_"
            $spnComputers = @()
        }

        foreach ($c in $spnComputers) {
            try {
                Remove-ADComputer -Identity $c -Server $Server -Confirm:$false -ErrorAction Stop
                Write-AS2GoOutput -Type Success -Message "Removed SPN target computer '$($c.Name)'." -NoExtraLines
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Failed to remove SPN target computer '$($c.Name)': $_"
            }
        }
    }

    Measure-FunctionRuntime -End -Details $Info
}
