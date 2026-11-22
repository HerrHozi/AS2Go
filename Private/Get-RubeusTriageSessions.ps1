<#
.SYNOPSIS
Parses Rubeus triage output and returns the user logon sessions with Kerberos tickets.

.DESCRIPTION
Reads Rubeus triage output and extracts one record per logon session (LUID).
Supports the pipe-separated triage table ("| LUID | UserName | Service | EndTime |") with
"SamAccountName @ FQDN" in the user column, and the legacy block format with
"LUID: 0x...; UserName: ..." header lines followed by indented ticket lines.
Computer accounts (trailing dollar sign) and sessions without any TGT or service
ticket are excluded.

.PARAMETER TriageOutput
Complete text output of a Rubeus triage run.

.OUTPUTS
Custom objects with LUID, UserName, TGTSpn, and ServiceSpn.

.EXAMPLE
Get-RubeusTriageSessions -TriageOutput (.\Rubeus.exe triage | Out-String)

Parses the triage output and lists the usable Pass-the-Ticket candidates.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Parses Rubeus triage output into per-session records with TGT and service ticket SPNs.
Filters computer accounts and empty sessions so only usable Pass-the-Ticket candidates remain.
#>
function Get-RubeusTriageSessions {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TriageOutput
    )

    $Info = Measure-FunctionRuntime -Begin

    $found = [ordered]@{}
    $curLuid = $null

    foreach ($line in ($TriageOutput -split "`r?`n")) {

        # Rubeus table row: "| LUID | UserName | Service | EndTime |"
        If ($line -match '^\s*\|\s*(0x[0-9a-fA-F]+)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*[^|]*?\s*\|\s*$') {
            $luid = $Matches[1]
            $userName = ($Matches[2] -split '\s+@\s+')[0].Trim()
            $spn = $Matches[3].Trim()

            If (-not $found.Contains($luid)) {
                $found[$luid] = [pscustomobject]@{
                    LUID       = $luid
                    UserName   = $userName
                    TGTSpn     = ''
                    ServiceSpn = ''
                }
            }

            If ($spn) {
                If ($spn -match '^krbtgt/') {
                    If (-not $found[$luid].TGTSpn) { $found[$luid].TGTSpn = $spn }
                }
                elseif (-not $found[$luid].ServiceSpn) {
                    $found[$luid].ServiceSpn = $spn
                }
            }
        }
        # Legacy triage header: "LUID: 0x...; UserName: ...;"
        elseif ($line -match 'LUID:\s*(0x[0-9a-fA-F]+).*?UserName:\s*([^\s;]+)') {
            $curLuid = $Matches[1]
            If (-not $found.Contains($curLuid)) {
                $found[$curLuid] = [pscustomobject]@{
                    LUID       = $curLuid
                    UserName   = $Matches[2]
                    TGTSpn     = ''
                    ServiceSpn = ''
                }
            }
        }
        # Legacy ticket line: "   krbtgt   krbtgt/DOMAIN   <date>"
        elseif ($curLuid -and $line -match '^\s*(\S+)\s+([^\s]+/[^\s]+)\s+\d{1,2}/\d{1,2}/\d{4}') {
            $spn = $Matches[2]
            If ($found.Contains($curLuid)) {
                If ($spn -match '^krbtgt/') {
                    If (-not $found[$curLuid].TGTSpn) { $found[$curLuid].TGTSpn = $spn }
                }
                elseif (-not $found[$curLuid].ServiceSpn) {
                    $found[$curLuid].ServiceSpn = $spn
                }
            }
        }
    }

    $sessions = @($found.Values | Where-Object { $_.UserName -notlike '*$' -and ($_.TGTSpn -or $_.ServiceSpn) })

    write-log INFO -Message "Get-RubeusTriageSessions >> Parsed $($sessions.Count) eligible user logon sessions from Rubeus triage output."

    Measure-FunctionRuntime -End -Details $Info

    return $sessions
}
