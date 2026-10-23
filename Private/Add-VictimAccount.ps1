<#
.SYNOPSIS
Creates one victim Active Directory user using time-based names.

.DESCRIPTION
Creates one VI- account with the attributes from New-AS2GoUsers.ps1.
Adds the account to SG-AS2Go-Victims only if that group exists.

.PARAMETER Shortname
Use 'y' for yyyyMMdd (default), 'n' for yyyyMMdd.HHmmssff, or a custom name.

.PARAMETER AccountPassword
Password for the new account. Prompts securely when omitted.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Creates one victim account with time-based attributes and optional victim group membership.
#>
function Add-VictimAccount {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetOU,
        [string]$UPNSuffix,
        [Parameter(Mandatory)][string]$Server,
        [ValidateNotNullOrEmpty()][string]$Shortname = "n",
        [System.Security.SecureString]$AccountPassword
    )

    $Info = Measure-FunctionRuntime -Begin

    try {
        $ou = Initialize-ADOUPath -DistinguishedName $TargetOU -Server $Server
        $UPNSuffix = if ([string]::IsNullOrWhiteSpace($UPNSuffix)) {
            Set-UPNSuffix
        }
        else {
            $UPNSuffix
        }
        if ([string]::IsNullOrWhiteSpace($UPNSuffix)) {
            throw "A UPN suffix is required to create the victim account."
        }
        if (-not $UPNSuffix.StartsWith("@")) {
            $UPNSuffix = "@$UPNSuffix"
        }

        $sFirstName = Get-Date -Format HHmmss
        $sLastname = Get-Date -Format yyyyMMdd
        $sNewName = switch ($Shortname) {
            "y" { $sLastname }
            "n" { "$sLastname.$sFirstName" }
            default { $Shortname }
        }
        $samAccountName = "VI-$sNewName"
        if ($samAccountName.Length -gt 20) {
            throw "The generated victim SamAccountName '$samAccountName' exceeds the 20-character Active Directory limit."
        }

        $sDisplayName = "Compromised Credentials ($samAccountName)"
        $UserProperties = @{
            "mobile"                     = Get-Date -Format HHmmssffff
            "telephoneNumber"            = Get-Date -Format HHmmssffff
            "employeenumber"             = Get-Date -Format HHmmssffff
            "GivenName"                  = $sFirstName
            "sn"                         = $sLastname
            "DisplayName"                = $sDisplayName
            "Company"                    = "Herr Hozi INC."
            "Description"                = "AS2Go Dummy User"
            "c"                          = "DE"
            "countryCode"                = 276
            "co"                         = "Germany"
            "l"                          = "somewhere in Germany"
            "wWWHomePage"                = "https://HerrHozi.com"
            "physicalDeliveryOfficeName" = "AS2Go Lab"
        }

        $VIGroup = Get-ADGroup -Filter 'SamAccountName -eq "SG-AS2Go-Victims"' -Server $Server -ErrorAction Stop
        
        if ($null -eq $AccountPassword) {
            $AccountPassword = Read-Host -Prompt "Password for victim user '$samAccountName'" -AsSecureString
        }

        New-ADUser `
            -Name "$sNewName-VI" `
            -SamAccountName $samAccountName `
            -UserPrincipalName ($samAccountName + $UPNSuffix) `
            -Department "Tier 2" `
            -Title "Normal User" `
            -Initials "VI" `
            -AccountPassword $AccountPassword `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -Path $ou.DistinguishedName `
            -Server $Server `
            -ErrorAction Stop

        Set-ADUser `
            -Identity $samAccountName `
            -Replace $UserProperties `
            -Server $Server `
            -ErrorAction Stop

        if ($null -ne $VIGroup) {
            Add-ADGroupMember `
                -Identity $VIGroup `
                -Members $samAccountName `
                -Server $Server `
                -ErrorAction Stop
        }
        else {
            Write-AS2GoOutput -Type Warning -Message "Group 'SG-AS2Go-Victims' does not exist. Victim user '$samAccountName' was created without this membership."
        }

        Write-AS2GoOutput -Type Success -Message "Created victim user '$samAccountName'."
    }
    finally {
        if ($Info) {
            Measure-FunctionRuntime -End -Details $Info
        }
    }
}
