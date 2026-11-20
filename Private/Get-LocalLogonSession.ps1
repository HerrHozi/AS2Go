<#
.SYNOPSIS
Lists locally logged-on users and identifies their likely session type.

.DESCRIPTION
Combines terminal session data, process owners, and Windows logon sessions to
identify console, RDP, RunAs, and other interactive logons.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
Get-LocalLogonSession |
    Where-Object { $_.HasProcesses -eq $true } |
    Sort-Object StartTime -Descending -ErrorAction SilentlyContinue |
    Group-Object -Property Domain, UserName |
    ForEach-Object {
        $_.Group | Select-Object -First 1
    } |
    Format-Table Domain, UserName, DetectedType, StartTime, HasProcesses, TerminalSession -AutoSize
Returns the most recent session with a running process for each domain and user.

.NOTES
Requires Windows. Run as Administrator to retrieve process owners.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Lists local logon sessions and distinguishes console, RDP, and likely RunAs logons.
#>
function Get-LocalLogonSession {
    [CmdletBinding()]
    param()

    $Info = Measure-FunctionRuntime -Begin

    try {
        $TerminalSessions = @(
            & qwinsta.exe |
                ForEach-Object {
                    if ($_ -match '^\s*>?(?<SessionName>\S+)\s+(?<UserName>\S+)?\s+(?<SessionId>\d+)\s+(?<State>Active|Disc)\b') {
                        [pscustomobject]@{
                            SessionName = $Matches.SessionName
                            UserName    = $Matches.UserName
                            SessionId   = [int]$Matches.SessionId
                            State       = $Matches.State
                        }
                    }
                }
        )

        $ProcessUsers = @{}
        Get-Process -IncludeUserName -ErrorAction Stop |
            Where-Object UserName |
            ForEach-Object {
                $ProcessUsers[$_.UserName] = $true
            }

        $LogonSessions = Get-CimInstance -ClassName Win32_LogonSession -ErrorAction Stop
        $LoggedOnUsers = Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction Stop

        $SessionLookup = @{}
        foreach ($Session in $LogonSessions) {
            $SessionLookup[$Session.LogonId] = $Session
        }

        foreach ($Entry in $LoggedOnUsers) {
            $Domain = $Entry.Antecedent.Domain
            $User = $Entry.Antecedent.Name

            if ($Domain -in @('NT AUTHORITY', 'NT SERVICE', 'BUILTIN', 'Window Manager')) {
                continue
            }

            $LogonId = $Entry.Dependent.LogonId
            $Session = $SessionLookup[$LogonId]
            if (-not $Session) {
                continue
            }

            $FullUserName = "$Domain\$User"
            $HasProcess = $ProcessUsers.ContainsKey($FullUserName)
            $TerminalSession = $TerminalSessions |
                Where-Object { $_.UserName -eq $User -and $_.State -eq 'Active' } |
                Select-Object -First 1

            if ($TerminalSession) {
                if ($TerminalSession.SessionName -eq 'console') {
                    $DetectedType = 'Direct / Console'
                }
                elseif ($TerminalSession.SessionName -like 'rdp-tcp*') {
                    $DetectedType = 'MSTSC / RDP'
                }
                else {
                    $DetectedType = "Terminal session: $($TerminalSession.SessionName)"
                }
            }
            elseif ($HasProcess -and $Session.LogonType -eq 2) {
                $DetectedType = 'Run as different user (likely)'
            }
            elseif ($Session.LogonType -eq 9) {
                $DetectedType = 'RunAs / NewCredentials (runas /netonly)'
            }
            elseif ($Session.LogonType -eq 10) {
                $DetectedType = 'MSTSC / RDP'
            }
            elseif ($Session.LogonType -eq 2) {
                $DetectedType = 'Interactive logon (Direct or Run as different user)'
            }
            else {
                $DetectedType = "LogonType $($Session.LogonType)"
            }

            [pscustomobject]@{
                Domain          = $Domain
                UserName        = $User
                DetectedType    = $DetectedType
                LogonType       = $Session.LogonType
                LogonId         = $LogonId
                StartTime       = $Session.StartTime
                HasProcesses    = $HasProcess
                TerminalSession = if ($TerminalSession) { $TerminalSession.SessionName } else { $null }
                SessionState    = if ($TerminalSession) { $TerminalSession.State } else { $null }
            }
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $Info
    }
}
