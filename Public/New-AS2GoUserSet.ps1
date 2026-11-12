<#
.SYNOPSIS
Creates the AS2Go lab users and a Tier 0 service account.

.DESCRIPTION
Creates up to five lab users and one service account in the configured Active Directory OUs.
Each user joins its configured security group. All accounts share the supplied master password,
use the lab thumbnail, and expire after seven days.

.PARAMETER DAUser
SamAccountName for the Tier 0 domain administrator.

.PARAMETER EAUser
SamAccountName for the Tier 0 enterprise administrator.

.PARAMETER SAUser
SamAccountName for the Tier 1 server administrator.

.PARAMETER HDUser
SamAccountName for the Tier 2 help desk user.

.PARAMETER VIUser
SamAccountName for the Tier 2 victim user.

.PARAMETER SrvAccount
SamAccountName for the Tier 0 service account.

.PARAMETER Shortname
Optional suffix for legacy account names. Use 'y' for yyyyMMdd, 'n' for yyyyMMdd.HHmmss,
or a custom suffix. Explicit account names take precedence.

.PARAMETER SkipDomainAdmin
Skips the domain administrator.

.PARAMETER SkipHelpDesk
Skips the help desk user and service account.

.PARAMETER SkipVictim
Skips the victim user.

.PARAMETER Server
Writable domain controller or domain to use for Active Directory operations. Defaults to the current domain.

.PARAMETER MasterPassword
Shared password for every created account. At least seven characters to satisfy
the default Active Directory password complexity requirements.

.EXAMPLE
New-AS2GoUserSet -WhatIf

.EXAMPLE
New-AS2GoUserSet -DAUser AS2go-T0-Adm -VIUser AS2go -SkipHelpDesk -MasterPassword 'P@ssw0rd!'

.COMPONENT
Category: Lab Setup

.FUNCTIONALITY
Creates five lab users with configured group memberships and a separate Tier 0 service account.
#>
function New-AS2GoUserSet {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateNotNullOrEmpty()][string]$Shortname,
        [AllowNull()][ValidateLength(7, 256)][string]$MasterPassword,
        [switch]$SkipDomainAdmin,
        [switch]$SkipHelpDesk,
        [switch]$SkipVictim,
        [ValidateLength(1, 20)][string]$DAUser = 'AS2go-T0-Adm',
        [ValidateLength(1, 20)][string]$EAUser = 'AS2go-T0-Ent',
        [ValidateLength(1, 20)][string]$SAUser = 'AS2go-T1-Adm',
        [ValidateLength(1, 20)][string]$HDUser = 'AS2go-T2-Admm',
        [ValidateLength(1, 20)][string]$VIUser = 'AS2go',
        [ValidateLength(1, 20)][string]$SrvAccount = 'As2go-T0-SvcAccount',
        [ValidateNotNullOrEmpty()][string]$Server
        # 7 characters satisfies the default Active Directory password complexity policy.
        # AllowNull keeps 'New-AS2GoUserSet -WhatIf' working without a password.

    )

    $info = Measure-FunctionRuntime -Begin

    try {
        Write-AS2GoOutput -Type Header -Message 'Create AS2Go Lab Accounts'
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $accounts = @(
            @{ Parameter = 'DAUser'; Name = $DAUser; Prefix = 'DA'; Title = 'Domain Administrator'; Tier = 'Tier 0'; OU = 'T0AccountsOU'; Group = 'DAGroup'; Skip = $SkipDomainAdmin }
            @{ Parameter = 'EAUser'; Name = $EAUser; Prefix = 'EA'; Title = 'Enterprise Administrator'; Tier = 'Tier 0'; OU = 'T0AccountsOU'; Group = 'EAGroup' }
            @{ Parameter = 'SAUser'; Name = $SAUser; Prefix = 'SA'; Title = 'Server Administrator'; Tier = 'Tier 1'; OU = 'T1AccountsOU'; Group = 'SAGroup' }
            @{ Parameter = 'HDUser'; Name = $HDUser; Prefix = 'HD'; Title = 'Help Desk'; Tier = 'Tier 2'; OU = 'T2AccountsOU'; Group = 'HDGroup'; Skip = $SkipHelpDesk }
            @{ Parameter = 'VIUser'; Name = $VIUser; Prefix = 'VI'; Title = 'Normal User'; Tier = 'Tier 2'; OU = 'T2AccountsOU'; Group = 'VIGroup'; Skip = $SkipVictim }
            @{ Parameter = 'SrvAccount'; Name = $SrvAccount; Prefix = 'SVC'; Title = 'Service Account'; Tier = 'Tier 0'; OU = 'T0ServiceAccountsOU'; Skip = $SkipHelpDesk }
        ) | Where-Object { -not $_.Skip }

        $now = Get-Date
        $suffix = switch ($Shortname) {
            'y' { $now.ToString('yyyyMMdd') }
            'n' { $now.ToString('yyyyMMdd.HHmmss') }
            default { $Shortname }
        }

        $settings = @{}
        $accountNames = @{}
        foreach ($account in $accounts) {
            if ($suffix -and -not $PSBoundParameters.ContainsKey($account.Parameter)) {
                $account.Name = "$($account.Prefix)-$suffix"
            }
            if ($account.Name.Length -gt 20 -or $account.Name -match '[\x00-\x1f"\[\]:;|=+,*?<>/\\@]' -or $account.Name -match '^\s|[.\s]$') {
                throw "Invalid Active Directory account name '$($account.Name)'. Use a valid SamAccountName of at most 20 characters."
            }
            if ($accountNames.ContainsKey($account.Name)) {
                throw "Account name '$($account.Name)' is used more than once."
            }
            $accountNames[$account.Name] = $true

            foreach ($setting in @($account.OU, $account.Group)) {
                if ($setting -and -not $settings.ContainsKey($setting)) {
                    $value = Get-ASConfig -Setting $setting
                    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
                        throw "AS2Go setting '$setting' must contain a single non-empty value."
                    }
                    $settings[$setting] = $value
                }
            }
        }

        $thumbnailPhoto = [System.IO.File]::ReadAllBytes((Join-Path -Path $Script:ASSetup -ChildPath 'AS2Go-Admin.jpg'))

        Import-Module ActiveDirectory -ErrorAction Stop
        if (-not $Server) {
            $Server = (Get-ADDomainController -Discover -Writable -ErrorAction Stop).HostName
        }
        $adParameters = @{ Server = $Server; ErrorAction = 'Stop' }
        $upnSuffix = Get-ASConfig -Setting 'LastUPNSuffix'
        if ([string]::IsNullOrWhiteSpace($upnSuffix)) {
            $upnSuffix = (Get-ADDomain @adParameters).DNSRoot
        }
        $upnSuffix = $upnSuffix.TrimStart('@')
        $password = $null

        foreach ($account in $accounts) {
            $account.Path = (Get-ADOrganizationalUnit -Identity $settings[$account.OU] @adParameters).DistinguishedName
            if ($account.Group) {
                $account.GroupDN = (Get-ADGroup -Identity $settings[$account.Group] @adParameters).DistinguishedName
            }

            $samAccountName = $account.Name
            if (Get-ADUser -Filter { SamAccountName -eq $samAccountName } @adParameters) {
                throw "Account '$samAccountName' already exists on '$Server'."
            }
        }

        foreach ($account in $accounts) {
            $action = "Create $($account.Title) in '$($account.Path)' on '$Server'"
            if ($account.GroupDN) {
                $action += " and add it to '$($account.GroupDN)'"
            }
            if (-not $PSCmdlet.ShouldProcess($account.Name, $action)) {
                continue
            }

            $userParameters = @{
                Name                  = $account.Name
                SamAccountName        = $account.Name
                UserPrincipalName     = "$($account.Name)@$upnSuffix"
                DisplayName           = "$($account.Title) ($($account.Name))"
                Title                 = $account.Title
                Department            = $account.Tier
                Initials              = $account.Prefix
                Description           = 'AS2Go Lab Account'
                Path                  = $account.Path
                AccountExpirationDate = $now.AddDays(7)
                OtherAttributes       = @{ thumbnailPhoto = $thumbnailPhoto }
                Enabled               = $false
            }
            if (-not $password) {
                if ([string]::IsNullOrWhiteSpace($MasterPassword)) {
                    throw 'Parameter -MasterPassword must contain the shared password for the created lab accounts.'
                }
                $password = ConvertTo-SecureString -String $MasterPassword -AsPlainText -Force
            }
            $user = New-ADUser @userParameters @adParameters -AccountPassword $password -PassThru -Confirm:$false
            if ($account.GroupDN) {
                Add-ADGroupMember -Identity $account.GroupDN -Members $user @adParameters -Confirm:$false
            }
            Enable-ADAccount -Identity $user @adParameters -Confirm:$false
            $CN = Convert-FromDNToCN -DistinguishedName $account.Path
            $CN += "/$($account.Name)"
            Write-AS2GoOutput -Type Success -Message ("Created {0,-26} '{1}'." -f $account.Title, $CN) -NoExtraLines
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}
