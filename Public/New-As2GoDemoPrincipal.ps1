<#
.SYNOPSIS
Creates the AS2Go lab users and a Tier 0 service account.

.DESCRIPTION
Creates up to five lab users and one service account in the configured Active Directory OUs.
Each user joins its configured security group. All accounts share the supplied master password,
use the lab thumbnail, and expire after seven days. The service account additionally receives a
random SPN that points to a newly created SPN target computer, making it Kerberoastable.

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
SamAccountName for the Tier 0 service account. Receives a random SPN that is hosted by a newly
created computer named 'SRV-' plus the account name truncated to 15 characters.

.PARAMETER ShortName
Replaces the AS2go prefix while keeping the standard account suffixes.
Explicit account names take precedence. Use up to six characters if creating the default service account name.

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
New-As2GoDemoPrincipal -ShortName Lab01 -WhatIf

.EXAMPLE
New-As2GoDemoPrincipal -DAUser AS2go-T0-Adm -VIUser AS2go -SkipHelpDesk -MasterPassword 'P@ssw0rd!'

.COMPONENT
Category: Lab Setup

.FUNCTIONALITY
Creates six lab principals with configured group memberships and a Tier 0 service account that
receives a Kerberoastable SPN on a dedicated SPN target computer.
#>
function New-As2GoDemoPrincipal {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateNotNullOrEmpty()][ValidateLength(1, 13)][string]$ShortName,
        [System.Security.SecureString]$InititalPassword, 
        [switch]$SkipDomainAdmin,
        [switch]$SkipHelpDesk,
        [switch]$SkipVictim,
        [ValidateLength(1, 13)][string]$DAUser = 'AS2go-T0-Adm',
        [ValidateLength(1, 20)][string]$EAUser = 'AS2go-T0-Ent',
        [ValidateLength(1, 20)][string]$SAUser = 'AS2go-T1-Adm',
        [ValidateLength(1, 20)][string]$HDUser = 'AS2go-T2-Adm',
        [ValidateLength(1, 20)][string]$VIUser = 'AS2go',
        [ValidateLength(1, 20)][string]$SrvAccount = 'As2go-T0-SA',
        [ValidateNotNullOrEmpty()][string]$Server,
        [Switch]$EnableLogging
        # 7 characters satisfies the default Active Directory password complexity policy.
        # AllowNull keeps 'New-As2GoDemoPrincipal -WhatIf' working without a password.
    )

    $info = Measure-FunctionRuntime -Begin

    if (-not $InititalPassword) {

        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
        Write-AS2GoOutput -Type Bullet -Message 'Tier 0 Domain Administrator Account'
        Write-AS2GoOutput -Type Bullet -Message 'Tier 0 Enterprise Account'
        Write-AS2GoOutput -Type Bullet -Message 'Tier 1 Server Operator'
        Write-AS2GoOutput -Type Bullet -Message 'Tier 2 Help Desk Account'
        Write-AS2GoOutput -Type Bullet -Message 'Tier 2 Victim Account'
        Write-AS2GoOutput -Type Bullet -Message 'Tier 0 Service Account including an SPN'
        

        $RandomPw = Get-RandomPassword
        Write-Host "`n`n[~] Enter initial password or press Enter for random one $RandomPw    : " -NoNewline -ForegroundColor Cyan
        #$newpw = Write-AS2GoOutput -Type Input -Message "Enter initial password or press Enter for random   $RandomPw   "

        $newpw = Read-Host -AsSecureString
        $plainText = [System.Net.NetworkCredential]::new('', $newpw).Password
        Set-ASConfig -setting "LastPw" -value $plainText

        if ($newpw.Length -eq 0) {
            $InititalPassword = ConvertTo-SecureString $RandomPw -AsPlainText -Force
        }
        else {
            $InititalPassword = $newpw
        }
    }  


    try {


        $accounts = @(
            @{ Parameter = 'DAUser'; Name = $DAUser; Prefix = 'DA'; Title = 'Domain Administrator'; Tier = 'Tier 0'; OU = 'T0AccountsOU'; Group = 'DAGroup'; Skip = $SkipDomainAdmin }
            @{ Parameter = 'EAUser'; Name = $EAUser; Prefix = 'EA'; Title = 'Enterprise Administrator'; Tier = 'Tier 0'; OU = 'T0AccountsOU'; Group = 'EAGroup' }
            @{ Parameter = 'SAUser'; Name = $SAUser; Prefix = 'SA'; Title = 'Server Administrator'; Tier = 'Tier 1'; OU = 'T1AccountsOU'; Group = 'SAGroup' }
            @{ Parameter = 'HDUser'; Name = $HDUser; Prefix = 'HD'; Title = 'Help Desk User'; Tier = 'Tier 2'; OU = 'T2AccountsOU'; Group = 'HDGroup'; Skip = $SkipHelpDesk }
            @{ Parameter = 'VIUser'; Name = $VIUser; Prefix = 'VI'; Title = 'Normal / Compromised User'; Tier = 'Tier 2'; OU = 'T2AccountsOU'; Group = 'VIGroup'; Skip = $SkipVictim }
            @{ Parameter = 'SrvAccount'; Name = $SrvAccount; Prefix = 'SVC'; Title = 'Service Account'; Tier = 'Tier 0'; OU = 'T0ServiceAccountsOU'; Group = 'DAGroup'; Skip = $SkipHelpDesk; SPN = $true }
        ) | Where-Object { -not $_.Skip }

        $now = Get-Date

        $settings = @{}
        $accountNames = @{}
        foreach ($account in $accounts) {
            if ($PSBoundParameters.ContainsKey('ShortName') -and -not $PSBoundParameters.ContainsKey($account.Parameter)) {
                $separator = $account.Name.IndexOf('-')
                $account.Name = if ($separator -ge 0) {
                    $ShortName + $account.Name.Substring($separator)
                }
                else {
                    $ShortName
                }
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
                if ([string]::IsNullOrWhiteSpace($InititalPassword)) {
                    throw 'Parameter -MasterPassword must contain the shared password for the created lab accounts.'
                }
                #$password = ConvertTo-SecureString -String $InititalPassword -AsPlainText -Force
            }
            $user = New-ADUser @userParameters @adParameters -AccountPassword $InititalPassword -PassThru -Confirm:$false
            if ($account.GroupDN) {
                Add-ADGroupMember -Identity $account.GroupDN -Members $user @adParameters -Confirm:$false
            }
            Enable-ADAccount -Identity $user @adParameters -Confirm:$false
            $CN = Convert-FromDNToCN -DistinguishedName $account.Path
            $CN += "/$($account.Name)"
            Write-AS2GoOutput -Type Success -Message ("Created {0,-26} '{1}'." -f $account.Title, $CN) -NoExtraLines

            if ($account.SPN) {
                # Give the service account at least one Kerberoastable SPN that is hosted by a dedicated lab computer.
                $services = @('HTTPS', 'FTP', 'CIFS', 'kafka', 'MSSQL', 'POP3', 'HTTP')
                $spnComputer = 'SRV-' + $account.Name
                if ($spnComputer.Length -gt 15) {
                    $spnComputer = $spnComputer.Substring(0, 15)
                }
                $spnComputerSam = '{0}$' -f $spnComputer
                if (Get-ADComputer -Filter { SamAccountName -eq $spnComputerSam } -Server $Server -ErrorAction SilentlyContinue) {
                    throw "Computer '$spnComputer' already exists on '$Server'."
                }
                $spnPath = "OU=T0 Servers," + ($account.Path -split '(?<!\\),', 2)[1]
                $spnPathDN = (Get-ADOrganizationalUnit -Identity $spnPath -Server $Server -ErrorAction SilentlyContinue).DistinguishedName
                if (-not $spnPathDN) {
                    $spnPathDN = (Get-ADDomain -Server $Server).ComputersContainer
                }
                $spnService = $services | Get-Random
                $spn = "$spnService/$spnComputer"
                $spnAction = "Create computer '$spnComputer' in '$spnPathDN' and assign SPN '$spn'"
                if ($PSCmdlet.ShouldProcess($account.Name, $spnAction)) {
                    New-ADComputer -Name $spnComputer -Description 'AS2Go Lab Computer - needed for Kerberoasting Attack' `
                        -OperatingSystem 'Windows Server 2019 Standard' -Path $spnPathDN @adParameters -Confirm:$false
                    Set-ADUser -Identity $user -ServicePrincipalNames @{ Add = $spn } @adParameters -Confirm:$false
                    Write-AS2GoOutput -Type Success -Message "Assigned SPN '$spn' to '$($account.Name)' (SPN target computer '$spnComputer')." -NoExtraLines
                }
            }
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}
