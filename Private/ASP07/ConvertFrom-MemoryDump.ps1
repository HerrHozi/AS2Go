<#
.SYNOPSIS
Converts an LSASS wdigest text dump into session objects.

.DESCRIPTION
Parses the supplied text file and returns one object per Authentication Id block. Reads
session metadata, and the username, domain, and password from the wdigest section. Missing
fields and literal (null) values are returned as $null. Hex-encoded passwords from machine
accounts are returned as $null. LogonTime remains a string. Reads the file only; it does not
access LSASS, collect credentials, or authenticate.

.PARAMETER Path
Path to the text dump file.

.PARAMETER Unique
Returns the newest session per domain SID, limited to sessions with a plaintext password.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
$Sessions = @(ConvertFrom-MemoryDump -Path 'C:\Users\Public\AS2Go\Exfiltration\test2.log')
Collects the logon sessions in an array, including when zero or one session is found.

.COMPONENT
Category: Utility Function

.FUNCTIONALITY
Parses LSASS logon-session text into objects with session metadata and wdigest username, domain, and password details.
#>
function ConvertFrom-MemoryDump {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Switch]$Unique
    )

    $info = Measure-FunctionRuntime -Begin
    try {
        Write-AS2GoOutput -Type Header -Message 'Analyze Memory Dump'
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $Session = $null
        $Sessions = [System.Collections.Generic.List[object]]::new()
        $Section = $null
        foreach ($Line in (Get-Content -LiteralPath $Path -ErrorAction Stop)) {
            if ($Line -match '^\s*Authentication Id\s*:') {
                if ($null -ne $Session) {
                    $Sessions.Add([pscustomobject]$Session)
                }
                $Session = [ordered]@{
                    Session          = $null
                    LogonServer      = $null
                    LogonTime        = $null
                    SID              = $null
                    Username         = $null
                    Domain           = $null
                    Password         = $null
                }
                $Section = $null
                continue
            }
            if ($null -eq $Session) {
                continue
            }
            if ($Line -match '^\s*(Session|Logon Server|Logon Time|SID)\s*:\s*(.*?)\s*$') {
                $Property = $Matches[1] -replace ' ', ''
                $Value = $Matches[2]
                $Session[$Property] = if ($Value -eq '(null)' -or $Value.Length -eq 0) { $null } else { $Value }
            }
            elseif ($Line -match '^\s*wdigest\s*:') {
                $Section = 'wdigest'
            }
            elseif ($Line -match '^\s*\*\s*(Username|Domain|Password)\s*:\s*(.*?)\s*$') {
                $Property = $Matches[1]
                $Value = $Matches[2]
                $ClearedValue = if ($Value -eq '(null)' -or $Value.Length -eq 0 -or $Value -match '^\s*(?:[0-9a-fA-F]{2}\s+){5,}[0-9a-fA-F]{2}\s*$') { $null } else { $Value }
                $Session[$Property] = $ClearedValue
            }
        }

        if ($null -ne $Session) {
            $Sessions.Add([pscustomobject]$Session)
        }

        $UniqueSessions = $Unique ? (
            $Sessions |
            Where-Object {
                $null -ne $_.Password -and
                $_.SID -like 'S-1-5-21-*'
            } |
            Sort-Object -Property LogonTime -Descending |
            Group-Object -Property SID |
            ForEach-Object {
                $_.Group[0]
            }
        ) : $Sessions

        $UniqueSessions
    }
    finally {
        Write-Log -Message "Finished processing logon sessions from file: $Path found $($Sessions -and $Sessions.Count -gt 0 ? 'with valid sessions' : 'with no valid sessions')"
        Measure-FunctionRuntime -End -Details $info
    }
}