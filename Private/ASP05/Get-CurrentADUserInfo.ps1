<#
.SYNOPSIS
Gets information about the current Windows user and Active Directory account.

.DESCRIPTION
Resolves the current Windows identity to an Active Directory user and returns
account, domain, password policy, group membership, and session information.
The function queries the current domain's PDC emulator and includes both
Active Directory group membership and groups in the current Windows token.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Returns a summary of the current user's Active Directory account and security context.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
Get-CurrentADUserInfo
Returns information for the current Windows user and domain session.

.NOTES
Requires a domain-connected Windows session, the ActiveDirectory module, and
permissions to query the current user, group memberships, and domain password policy.
#>
function Get-CurrentADUserInfo {
    [CmdletBinding()]
    param()

    $info = Measure-FunctionRuntime -Begin

    # Get current Windows identity
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [System.Security.Principal.WindowsPrincipal]::new($Identity)

    # Get current domain information
    $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

    # Load Active Directory module
    Import-Module ActiveDirectory -ErrorAction Stop

    # Resolve the user through the current Windows SID
    $User = Get-ADUser `
        -Identity $Identity.User.Value `
        -Server $Domain.PdcRoleOwner.Name `
        -Properties * `
        -ErrorAction Stop

    # Get domain password policy
    $PasswordPolicy = Get-ADUserResultantPasswordPolicy `
        -Identity $User `
        -Server $Domain.PdcRoleOwner.Name `
        -ErrorAction SilentlyContinue

    if (-not $PasswordPolicy) {
        $PasswordPolicy = Get-ADDefaultDomainPasswordPolicy `
            -Server $Domain.PdcRoleOwner.Name
    }

    # Resolve effective security groups (including nested groups)
    $Groups = @(
        Get-ADPrincipalGroupMembership `
            -Identity $User `
            -Server $Domain.PdcRoleOwner.Name `
            -ErrorAction SilentlyContinue
    )

    # Get Windows access token group SIDs
    $TokenGroups = @(
        $Identity.Groups | ForEach-Object {
            $_.Translate(
                [System.Security.Principal.NTAccount]
            ).Value
        }
    )

    Measure-FunctionRuntime -End -Details $info

    # Build result
    [pscustomobject]@{
        # Identity
        UserName              = $Identity.Name
        SamAccountName        = $User.SamAccountName
        UserPrincipalName     = $User.UserPrincipalName
        DisplayName           = $User.DisplayName
        SID                   = $User.SID.Value
        DistinguishedName     = $User.DistinguishedName
        ObjectGUID            = $User.ObjectGUID

        # Domain
        Domain                = $Domain.Name
        DomainController      = $Domain.PdcRoleOwner.Name

        # Account status
        Enabled               = $User.Enabled
        LockedOut             = $User.LockedOut
        PasswordExpired       = $User.PasswordExpired
        PasswordNeverExpires  = $User.PasswordNeverExpires
        PasswordNotRequired   = $User.PasswordNotRequired
        PasswordLastSet       = $User.PasswordLastSet
        LastLogonDate         = $User.LastLogonDate
        AccountExpirationDate = $User.AccountExpirationDate
        BadLogonCount         = $User.BadLogonCount
        AdminCount            = $User.AdminCount

        # Security
        AuthenticationType    = $Identity.AuthenticationType
        #IsLocalAdministrator  = $Principal.IsInRole(
        #    [System.Security.Principal.WindowsBuiltInRole]::Administrator
       # )
        IsSystem              = $Identity.IsSystem
        IsGuest               = $Identity.IsGuest
        AuthenticationPolicy  = $User.AuthenticationPolicy
        AuthenticationSilo    = $User.AuthenticationPolicySilo

        # Password policy
        MinimumPasswordLength = $PasswordPolicy.MinPasswordLength
        MaxPasswordAge        = $PasswordPolicy.MaxPasswordAge
        LockoutThreshold      = $PasswordPolicy.LockoutThreshold

        # Groups
        PrimaryGroupID        = $User.PrimaryGroupID
        DirectMemberOf        = @($User.MemberOf)
        ADGroups              = @($Groups.Name)
        TokenGroups           = $TokenGroups

        # Session
        ComputerName          = $env:COMPUTERNAME
        LogonServer           = $env:LOGONSERVER
        UserDomain            = $env:USERDOMAIN
        UserDNSDomain         = $env:USERDNSDOMAIN
    }
}


