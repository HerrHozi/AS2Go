<#
.SYNOPSIS
Tests whether a value matches the selected Active Directory format.

.DESCRIPTION
Checks the syntax of an Active Directory name locally. The check does not look up
the value in Active Directory or DNS. Records Type, Value, and Result when AS2Go
logging is enabled. For Hash inputs, the logged value is redacted.

.PARAMETER Type
Selects the format to validate.
OU requires one or more OU components followed by one or more DC components.
Domain requires one or more DC components.
Principal requires a CN component, one or more OU components, and one or more DC components.
CN requires an LDAP prefix followed by a fully qualified DNS name, such as LDAP://test.com.
FQDN requires a fully qualified DNS name, such as test.com.
NTAccount requires a NetBIOS domain and account name, such as TEST\user.
Hash requires a fully qualified DNS name, an account name, and a nonempty hash
field separated by pipes. The hash field may contain Unicode characters.
GoldenTicket checks the first and last pipe-separated fields for a fully qualified DNS
name and an Active Directory domain SID. Intermediate fields are optional.

.PARAMETER Value
Specifies the value to validate. Empty values return False.

.EXAMPLE
Test-ADFormat -Type OU -Value 'OU=Test,DC=test,DC=com'

Returns True for an organizational unit distinguished name.

.EXAMPLE
Test-ADFormat -Type OU -Value 'OU=Test,DC=test.,DC=com'

Returns False because a DC component must contain a single DNS label.

.EXAMPLE
Test-ADFormat -Type Hash -Value 'test.com|user|samplehash'

Returns True for a pipe-separated domain, account name, and hash field.

.EXAMPLE
Test-ADFormat -Type GoldenTicket -Value 'test.com|xxx|dddd|dddddd|ddd|S-1-5-21-1-2-3'

Returns True because the first field is a DNS name and the last field is a domain SID.

.OUTPUTS
System.Boolean

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Checks whether a value matches the selected Active Directory name format.
#>
function Test-ADFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('OU', 'Domain', 'Principal', 'CN', 'FQDN', 'NTAccount', 'Hash', 'GoldenTicket')]
        [string]$Type,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    $info = Measure-FunctionRuntime -Begin

    try {
        #Write-AS2GoOutput -Type Header -Message 'Test Active Directory Format'
        #Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $DnsLabel = '[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
        $DnsName = "(?:$DnsLabel\.)+$DnsLabel"
        $Fqdn = "(?=[a-z0-9.-]{1,253}\z)$DnsName"
        $DomainDn = "DC=$DnsLabel(?:, *DC=$DnsLabel)*"
        $DnEscape = '\\(?:[0-9a-f]{2}|[ ,+"\\<>;=#])'
        $DnCharacter = '[^,+"\\<>;=\x00-\x1f\x7f]'
        $DnValue = "(?![ #])(?:$DnEscape|$DnCharacter)*(?:$DnEscape|[^ ,+`"\\<>;=\x00-\x1f\x7f])"
        $OuDn = "(?:OU=$DnValue, *)+$DomainDn"
        $NetBiosName = '[a-z0-9](?:[a-z0-9-]{0,13}[a-z0-9])?'
        $AccountName = '(?!\s)[^"\x00-\x1f\x7f/\\\[\]:;|=,+*?<>]+(?<!\s)'

        $Pattern = switch ($Type) {
            'OU'        { $OuDn }
            'Domain'    { $DomainDn }
            'Principal' { "CN=$DnValue, *$OuDn" }
            'CN'        { "LDAP://$Fqdn" }
            'FQDN'      { $Fqdn }
            'NTAccount' { "$NetBiosName\\$AccountName" }
            'Hash'      { "(?=[a-z0-9.-]{1,253}\|)$DnsName\|$AccountName\|[^|\s\p{C}]+" }
            'GoldenTicket'    { "(?=[a-z0-9.-]{1,253}\|)$DnsName\|(?:[^|]*\|)*S-1-5-21-(?<DomainId>[0-9]{1,10}(?:-[0-9]{1,10}){2})" }
        }

        $Result = $Value -match "\A(?:$Pattern)\z"
        if ($Type -eq 'GoldenTicket' -and $Result) {
            foreach ($SubAuthority in ($Matches.DomainId -split '-')) {
                if ([uint64]$SubAuthority -gt [uint32]::MaxValue) {
                    $Result = $false
                    break
                }
            }
        }

        $LogValue = if ($Type -eq 'Hash') { '<redacted>' } else { $Value -replace '\p{C}', ' ' }
        $Message = "Type: $Type | Value: $LogValue | Result: $Result"
        #Write-AS2GoOutput -Type Info -Message $Message
        Write-Log -Message $Message | Out-Null
        return $Result
    }
    finally {
        Measure-FunctionRuntime -End -Details $info | Out-Null
    }
}
