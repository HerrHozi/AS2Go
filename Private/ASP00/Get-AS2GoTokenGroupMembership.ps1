<#
.SYNOPSIS
Resolves the security group membership of a user via an LDAP tokenGroups query.

.DESCRIPTION
Performs a base-level LDAP search against the user object on the given domain controller and
expands the computed tokenGroups attribute. It bypasses the Active Directory module so that a
broken ADWS endpoint on the local machine does not fail the membership lookup.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Resolves user group membership from the LDAP tokenGroups attribute as an
Active Directory module fallback and returns group names with their SIDs.
#>
function Get-AS2GoTokenGroupMembership {

    param(
        [Parameter(Mandatory)][string]$SamAccountName,
        [Parameter(Mandatory)][string]$Server
    )

    $info = Measure-FunctionRuntime -Begin

    try {
        $user = Get-ADUser -Identity $SamAccountName -Server $Server -Properties distinguishedName -ErrorAction Stop
        $entry = [System.DirectoryServices.DirectoryEntry]::new("LDAP://$Server/$($user.DistinguishedName)")
        $searcher = [System.DirectoryServices.DirectorySearcher]::new($entry, '(objectClass=*)', @('tokenGroups'), [System.DirectoryServices.SearchScope]::Base)
        $result = $searcher.FindOne()
        $searcher.Dispose()
        $entry.Dispose()
        if (-not $result) {
            Measure-FunctionRuntime -End -Details $info
            return @()
        }

        $groups = @(foreach ($rawSid in $result.Properties['tokengroups']) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new([byte[]]$rawSid, 0)
            $name = $sid.Value
            try { $name = ($sid.Translate([System.Security.Principal.NTAccount])).Value.Split('\')[-1] } catch { Write-Verbose "Could not translate SID '$($sid.Value)' to an account name." }
            [pscustomobject]@{ samaccountname = $name; sid = $sid }
        })

        Measure-FunctionRuntime -End -Details $info
        return $groups
    }
    catch {
        Write-Log -Message "    >> LDAP tokenGroups lookup for '$SamAccountName' on '$Server' failed: $_"
        Measure-FunctionRuntime -End -Details $info
        return @()
    }
}