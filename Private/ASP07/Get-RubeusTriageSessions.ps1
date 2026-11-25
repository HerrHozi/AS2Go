<#
.SYNOPSIS
Parses Rubeus triage output and returns the user logon sessions with Kerberos tickets.

.DESCRIPTION
Reads Rubeus triage output and extracts one record per logon session (LUID).
Supports the pipe-separated triage table ("| LUID | UserName | Service | EndTime |") with
"SamAccountName @ FQDN" in the user column, and the legacy block format with
"LUID: 0x...; UserName: ..." header lines followed by indented ticket lines.
Only a "krbtgt/<realm>" entry whose realm matches the session's own domain is treated as
the usable TGT; a "krbtgt/<other realm>" entry is a cross-realm referral ticket (seen when
only a trust-path ticket is cached, not the account's own domain TGT) and cannot be used to
request arbitrary new service tickets in the account's own domain, so it is kept separately
as CrossRealmTGTSpn instead. Computer accounts (trailing dollar sign) and sessions without
any TGT, referral ticket, or service ticket are excluded.

.PARAMETER TriageOutput
Complete text output of a Rubeus triage run.

.OUTPUTS
Custom objects with LUID, UserName, Domain, TGTSpn, TGTEndTime, CrossRealmTGTSpn, and ServiceSpn.

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
        If ($line -match '^\s*\|\s*(0x[0-9a-fA-F]+)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*$') {
            $luid = $Matches[1]
            $userParts = $Matches[2] -split '\s+@\s+'
            $userName = $userParts[0].Trim()
            $domain = If ($userParts.Count -gt 1) { $userParts[1].Trim() } else { '' }
            $spn = $Matches[3].Trim()
            $endTimeText = $Matches[4].Trim()

            If (-not $found.Contains($luid)) {
                $found[$luid] = [pscustomobject]@{
                    LUID             = $luid
                    UserName         = $userName
                    Domain           = $domain
                    TGTSpn           = ''
                    TGTEndTime       = $null
                    CrossRealmTGTSpn = ''
                    ServiceSpn       = ''
                }
            }

            If ($spn) {
                If ($spn -match '^krbtgt/(.+)$') {
                    # A "krbtgt/<realm>" entry is only a usable TGT when <realm> is the session's own
                    # domain. A different realm is a cross-realm referral/trust-path ticket - it lets
                    # Windows follow one specific trust, not request arbitrary new tickets in the
                    # account's own domain, so it must not be treated as "the TGT" for candidate selection.
                    If ($Matches[1].Trim() -eq $domain) {
                        If (-not $found[$luid].TGTSpn) {
                            $found[$luid].TGTSpn = $spn
                            # Used to prefer the longest-still-valid TGT when several sessions qualify.
                            $parsedEndTime = [datetime]::MinValue
                            If ([datetime]::TryParse($endTimeText, [ref]$parsedEndTime)) {
                                $found[$luid].TGTEndTime = $parsedEndTime
                            }
                        }
                    }
                    elseif (-not $found[$luid].CrossRealmTGTSpn) {
                        $found[$luid].CrossRealmTGTSpn = $spn
                    }
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
                    LUID             = $curLuid
                    UserName         = $Matches[2]
                    Domain           = ''
                    TGTSpn           = ''
                    TGTEndTime       = $null
                    CrossRealmTGTSpn = ''
                    ServiceSpn       = ''
                }
            }
        }
        # Legacy ticket line: "   krbtgt   krbtgt/DOMAIN   <date>"
        elseif ($curLuid -and $line -match '^\s*(\S+)\s+([^\s]+/[^\s]+)\s+(\d{1,2}/\d{1,2}/\d{4}.*)$') {
            $spn = $Matches[2]
            If ($found.Contains($curLuid)) {
                If ($spn -match '^krbtgt/') {
                    If (-not $found[$curLuid].TGTSpn) {
                        $found[$curLuid].TGTSpn = $spn
                        $parsedEndTime = [datetime]::MinValue
                        If ([datetime]::TryParse($Matches[3].Trim(), [ref]$parsedEndTime)) {
                            $found[$curLuid].TGTEndTime = $parsedEndTime
                        }
                    }
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
