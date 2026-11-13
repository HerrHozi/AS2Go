<#
.SYNOPSIS
Finds Active Directory user accounts by partial sign-in name across the current forest.

.DESCRIPTION
Searches the sAMAccountName in each domain of the current forest for a case-insensitive
literal substring. If a domain cannot be searched, the command reports the failure
and continues with the remaining domains.
If a domain's NetBIOS name cannot be resolved, the command warns and returns its matches
with an empty NetBIOSName.
If a password is supplied, every enabled match is checked against it and each account that
uses the password is reported. Failed checks count as logon attempts and may advance
account lockout counters.

.PARAMETER User
Specifies the literal substring to find in sAMAccountName.

.PARAMETER Password
Optional plain-text password checked against each enabled account found. Omit it to search
without credential checks.

.EXAMPLE
Find-ADForestUser -User 'As2go'

Finds accounts such as As2go, AS2Go.h, h.as2go, and h.as2go.h.

.EXAMPLE
Find-ADForestUser -User 'As2go' -Password 'Hozi-Lab!42'

Finds matching accounts and reports every enabled account that authenticates with the
supplied password.

.EXAMPLE
Find-ADForestUser -User 'As2go' -Password 'Hozi-Lab!42' | Select-object NetBIOSName, SamAccountName, Enabled, MemberOfRid, PasswordMatched | ft

Finds matching accounts and reports (incl. memberof) every enabled account that authenticates with the supplied password.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns the DNS and NetBIOS domain names, sign-in names, enabled status, and distinguished name of each match.
When a password is supplied, each match also contains its PasswordMatched status.

.NOTES
Requires the ActiveDirectory PowerShell module.
A supplied password triggers real logon checks; failed attempts can advance account lockout counters.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Finds accounts whose sign-in name contains the supplied text in any domain of the current forest.
With a supplied password, tests each enabled match and reports accounts that use that password.
#>
function Find-ADForestUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$User,
        [string]$Password
    )

    $info = Measure-FunctionRuntime -Begin

    try {
        Write-AS2GoOutput -Type Header -Message 'Find Active Directory Users Across the Forest'
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $EscapedUser = $User.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
        $LdapFilter = "(sAMAccountName=*$EscapedUser*)"
        $Forest = Get-ADForest -ErrorAction Stop

        $TestPassword = -not [string]::IsNullOrEmpty($Password)
        $DisabledSkippedCount = 0
        if ($TestPassword) {
            Write-AS2GoOutput -Type Warning -Message "The supplied password is checked against every enabled account found. Failed checks count as logon attempts and may advance account lockout counters."
        }

        $Results = [System.Collections.Generic.List[object]]::new()

        foreach ($Domain in $Forest.Domains) {
            try {
                $Accounts = Get-ADUser -Server $Domain -LDAPFilter $LdapFilter -Properties memberOf -ErrorAction Stop

                #   $Groups = Get-ADPrincipalGroupMembership -Server $Domain -Identity $Account.SamAccountName
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Could not search domain '$Domain'. $($_.Exception.Message)"
                continue
            }

            if (-not $Accounts) {
                continue
            }

            $NetBIOSName = $null
            try {
                $NetBIOSName = (Get-ADDomain -Identity $Domain -Server $Domain -ErrorAction Stop).NetBIOSName
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Could not resolve the NetBIOS name for domain '$Domain'. $($_.Exception.Message)"
            }

            $DomainController = $null
            if ($TestPassword) {
                try {
                    $DomainController = Get-BestDomainController -Domain $Domain
                }
                catch {
                    Write-AS2GoOutput -Type Warning -Message "Could not resolve a domain controller for domain '$Domain'. $($_.Exception.Message)"
                }
                if (-not $DomainController) {
                    Write-AS2GoOutput -Type Warning -Message "Password checks are skipped for domain '$Domain' because no domain controller was resolved."
                }
            }

            foreach ($Account in $Accounts) {
                $PasswordMatched = $false
                if ($TestPassword -and $DomainController) {
                    if ($Account.Enabled) {
                        $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
                        $Credential = New-Object System.Management.Automation.PSCredential $Account.SamAccountName, $SecurePassword
                        try {
                            $PasswordMatched = Test-ADLogon -Domain $Domain -Credential $Credential -DomainController $DomainController
                        }
                        catch {
                            $PasswordMatched = $false
                            Write-AS2GoOutput -Type Warning -Message "Could not check the password for '$Domain\$($Account.SamAccountName)'. $($_.Exception.Message)"
                        }
                    }
                    else {
                        $DisabledSkippedCount++
                    }
                }

                $membership = Get-ADGroup -LDAPFilter ("(member:1.2.840.113556.1.4.1941:=$($Account.DistinguishedName))") -Server $Domain | Select-Object *, @{N = 'RID'; E = { ($_.SID.value).split("-")[-1] } } | Sort-Object RID
                $rids = $membership.rid -join ", "
                $samaccountnames = $membership.samaccountname -join ", "


                $Result = [PSCustomObject]@{
                    Domain            = $Domain
                    NetBIOSName       = $NetBIOSName
                    SamAccountName    = $Account.SamAccountName
                    UserPrincipalName = $Account.UserPrincipalName
                    Enabled           = $Account.Enabled
                    DistinguishedName = $Account.DistinguishedName
                    MemberOf          = $samaccountnames
                    MemberOfRid       = $rids
                }

                if ($TestPassword) {
                    $Result | Add-Member -MemberType NoteProperty -Name PasswordMatched -Value $PasswordMatched
                }

                $Results.Add($Result)
                $Result
            }
        }

        if ($TestPassword -and $Results.Count -gt 0) {
            $MatchedAccounts = @($Results | Where-Object { $_.PasswordMatched })
            if ($MatchedAccounts.Count -gt 0) {
                Write-AS2GoOutput -Type TextMaker -Message "Accounts that use the supplied password:" -TM $MatchedAccounts.Count
                foreach ($MatchedAccount in $MatchedAccounts) {
                    $AccountName = if ($MatchedAccount.NetBIOSName) {
                        "$($MatchedAccount.NetBIOSName)\$($MatchedAccount.SamAccountName)"
                    }
                    else {
                        "$($MatchedAccount.Domain)\$($MatchedAccount.SamAccountName)"
                    }
                    Write-AS2GoOutput -Type Bullet -Message "Account '$AccountName' uses the supplied password"
                }
            }
            else {
                Write-AS2GoOutput -Type Warning -Message "None of the found accounts uses the supplied password."
            }

            if ($DisabledSkippedCount -gt 0) {
                Write-AS2GoOutput -Type Info -Message "Skipped password checks for $DisabledSkippedCount disabled account(s)."
            }
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}
