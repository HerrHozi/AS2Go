<#
.SYNOPSIS
    Creates a random Active Directory user using ADSI.

.EXAMPLE
    .\Add-RandomUser.ps1 -Domain "corp.local" -TargetOU "OU=TestUsers,DC=corp,DC=local"

.EXAMPLE
    .\Add-RandomUser.ps1 -Enabled
#>

[CmdletBinding()]
param(
    [string]$Domain,

    [string]$TargetOU,

    [string]$Password = (
        -join ((48..57) + (65..90) + (97..122) + (33, 35, 36, 37, 38, 42, 43, 45, 63) |
            Get-Random -Count 20 | ForEach-Object { [char]$_ })
    ),

    [switch]$Enabled
)

$ErrorActionPreference = 'Stop'

# Get the current domain root.
$rootDse = [ADSI]"LDAP://RootDSE"
$defaultNamingContext = $rootDse.defaultNamingContext.Value

if (-not $Domain) {
    $Domain = ($defaultNamingContext -split ',' |
        Where-Object { $_ -like 'DC=*' } |
        ForEach-Object { $_.Substring(3) }) -join '.'
}

if (-not $TargetOU) {
    $TargetOU = "CN=Users,$defaultNamingContext"
}

# Open the target container.
try {
    $container = [ADSI]"LDAP://$TargetOU"
    $null = $container.psbase.NativeObject
}
catch {
    throw "Target container is unreachable or does not exist: $TargetOU"
}

$FirstNames = @(
    'Max', 'Anna', 'Lukas', 'Emma', 'Felix', 'Mia', 'Jonas', 'Lena',
    'Paul', 'Sophie', 'Noah', 'Marie', 'Elias', 'Clara', 'Leon', 'Hanna'
)

$LastNames = @(
    'Mueller', 'Schmidt', 'Weber', 'Wagner', 'Becker', 'Hoffmann',
    'Schaefer', 'Koch', 'Richter', 'Klein', 'Wolf', 'Neumann'
)

$firstName = Get-Random -InputObject $FirstNames
$lastName = Get-Random -InputObject $LastNames

$displayName = "$firstName $lastName"

# Generate a unique SamAccountName.
do {
    $suffix = Get-Random -Minimum 1000 -Maximum 9999
    $samAccountName = ("{0}.{1}{2}" -f $firstName, $lastName, $suffix).ToLower()
    $samAccountName = $samAccountName.Substring(0, [Math]::Min(20, $samAccountName.Length))

    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$samAccountName))"
    $searcher.SearchRoot = [ADSI]"LDAP://$defaultNamingContext"
    $existing = $searcher.FindOne()
} while ($existing)

$upn = "$samAccountName@$Domain"

# Create the user object.
$user = $container.Create('user', "CN=$displayName")

$user.Put('sAMAccountName', $samAccountName)
$user.Put('userPrincipalName', $upn)
$user.Put('givenName', $firstName)
$user.Put('sn', $lastName)
$user.Put('displayName', $displayName)
$user.Put('description', 'Automatically created test user')

# Create the user as disabled.
$user.Put('userAccountControl', 514) # 512 = enabled, 514 = disabled

$user.SetInfo()

# Set the password.
$user.SetPassword($Password)

# Optionally enable the user.
if ($Enabled) {
    $user.Put('userAccountControl', 512)
    $user.SetInfo()
}

[PSCustomObject]@{
    DistinguishedName = $user.distinguishedName.Value
    DisplayName       = $displayName
    SamAccountName    = $samAccountName
    UserPrincipalName = $upn
    Enabled           = $Enabled.IsPresent
    InitialPassword   = $Password
}