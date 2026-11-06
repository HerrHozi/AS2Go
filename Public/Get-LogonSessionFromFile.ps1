<#
.SYNOPSIS
Extracts logon session details from an existing text log.

.DESCRIPTION
Returns one object per Authentication Id block. Reads session metadata, the NTLM value
from the msv section, and the username from the kerberos section. Domain contains the
NetBIOS domain from the session header; FQDN contains the domain from the kerberos section.
Missing fields and literal (null) values are returned as $null. LogonTime remains a string.
Only reads the supplied file; does not collect credentials or authenticate.

.PARAMETER Path
Path to the existing log file. Defaults to C:\Users\Public\AS2Go\Exfiltration\test.log.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
$Sessions = @(Get-LogonSessionFromFile)
Collects the logon sessions in an array, including when zero or one session is found.

.COMPONENT
Category: Utility Function

.FUNCTIONALITY
Extracts session metadata, NetBIOS domain, msv NTLM, and Kerberos username and FQDN from a text log.
#>
function Get-LogonSessionFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = 'C:\Users\Public\AS2Go\Exfiltration\test.log',
        [Switch]$EnableLogging
    )

    $info = Measure-FunctionRuntime -Begin
    try {
        Write-AS2GoOutput -Type Header -Message 'Read Logon Sessions'
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $Session = $null
        $Section = $null
        foreach ($Line in (Get-Content -LiteralPath $Path -ErrorAction Stop)) {
            if ($Line -match '^\s*Authentication Id\s*:') {
                if ($null -ne $Session) {
                    [pscustomobject]$Session
                }
                $Session = [ordered]@{
                    Session = $null
                    LogonServer = $null
                    LogonTime = $null
                    SID = $null
                    NTLM = $null
                    Username = $null
                    Domain = $null
                    FQDN = $null
                }
                $Section = $null
                continue
            }
            if ($null -eq $Session) {
                continue
            }
            if ($Line -match '^\s*(Session|Logon Server|Logon Time|SID|Domain)\s*:\s*(.*?)\s*$') {
                $Property = $Matches[1] -replace ' ', ''
                $Value = $Matches[2]
                $Session[$Property] = if ($Value -eq '(null)' -or $Value.Length -eq 0) { $null } else { $Value }
            }
            elseif ($Line -match '^\s*([a-zA-Z][\w-]*)\s*:\s*$') {
                $Section = $Matches[1]
            }
            elseif ($Line -match '^\s*\*\s*(Username|Domain|NTLM)\s*:\s*(.*?)\s*$') {
                $Property = $Matches[1]
                $Value = $Matches[2]
                if (($Section -eq 'msv' -and $Property -eq 'NTLM') -or
                    ($Section -eq 'kerberos' -and $Property -in 'Username', 'Domain')) {
                    if ($Section -eq 'kerberos' -and $Property -eq 'Domain') {
                        $Property = 'FQDN'
                    }
                    $Session[$Property] = if ($Value -eq '(null)' -or $Value.Length -eq 0) { $null } else { $Value }
                }
            }
        }
        if ($null -ne $Session) {
            [pscustomobject]$Session
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}

<#



$results = Get-LogonSessionFromFile -Path "C:\Users\Public\AS2Go\MaliciousTools\test.log" -EnableLogging

$uniqueResults =
    $results |
    Where-Object {
        $null -ne $_.NTLM -and
        $_.SID -like 'S-1-5-21-*'
    } |
    Sort-Object -Property LogonTime -Descending |
    Group-Object -Property SID |
    ForEach-Object {
        $_.Group[0]
    }

$BestResults = $uniqueResults |
ForEach-Object {
    $samAccountName = $_.Username
    $server         = $_.LogonServer

    $membership = @(
        Get-ADPrincipalGroupMembership `
            -Identity $samAccountName `
            -Server $server |
        Select-Object -Property Name, SID
    )

    $_ | Select-Object `
        Session,
        Domain,
        UserName,
        NTLM,
        SID,
        LogonTime,
        @{
            Name       = 'GroupMembership'
            Expression = {
                ($membership | ForEach-Object { $_.Name }) -join ', '
            }
        },
        @{
            Name       = 'GroupMembershipRids'
            Expression = {
                ($membership | ForEach-Object { $_.SID.Value.split('-')[-1] }) -join ', '
            }
        }
}

$BestResults  | Select-Object Domain, Username, NTLM, GroupMembershipRids



$BestPrincipal = foreach ($Rid in 519, 512, 548) {
    $MatchForRid = $BestResults | Sort-Object -Property LogonTime -Descending |
        Where-Object {
            $_.GroupMembershipRids -match "(?<!\d)$Rid(?!\d)"
        } |
        Select-Object -First 1

    if ($null -ne $MatchForRid) {
        $MatchForRid
        break
    }
}

$BestPrincipal | Select-Object Domain, Username, NTLM, GroupMembershipRids
