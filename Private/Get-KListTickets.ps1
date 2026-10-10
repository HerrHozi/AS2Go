

<#
.SYNOPSIS
Parses klist ticket output into structured ticket objects.

.DESCRIPTION
Parses output from klist tickets, or lines supplied through KlistOutput, into ticket objects.
Extracts client and server identities, encryption and cache flags, and ticket timestamps.
Attempts to parse ticket dates using the current, invariant, and en-US cultures.

.PARAMETER KlistOutput
Optional lines from klist tickets. Defaults to invoking klist tickets.

.OUTPUTS
System.Management.Automation.PSCustomObject. Parsed Kerberos ticket metadata.

.EXAMPLE
Get-KlistTicket

.EXAMPLE
Get-KlistTicket -KlistOutput $output

.FUNCTIONALITY
Parses klist ticket output into structured Kerberos ticket objects.

.COMPONENT
Category: Sub Function
#>
function Get-KlistTicket {
    [CmdletBinding()]
    param(
        [string[]]$KlistOutput = (klist tickets)
    )

    $tickets = [System.Collections.Generic.List[object]]::new()
    $current = $null

    foreach ($line in $KlistOutput) {
        switch -Regex ($line) {
            '^\s*#(?<Number>\d+)>' {
                if ($current) {
                    $tickets.Add($current)
                }

                $current = [PSCustomObject]@{
                    TicketNumber   = [int]$Matches.Number
                    Client         = $null
                    ClientDomain   = $null
                    Server         = $null
                    ServerDomain   = $null
                    EncryptionType = $null
                    TicketFlags    = $null
                    TicketFlagsHex = $null
                    StartTime      = $null
                    EndTime        = $null
                    RenewTime      = $null
                    SessionKeyType = $null
                    CacheFlags     = $null
                    CacheFlagsHex  = $null
                    KdcCalled      = $null
                }

                if ($line -match '^\s*#\d+>\s*Client:\s*(?<Client>[^\s]+)\s*@\s*(?<Domain>.+)$') {
                    $current.Client = $Matches.Client
                    $current.ClientDomain = $Matches.Domain.Trim()
                }
            }

            '^\s*Client:\s*(?<Client>[^\s]+)\s*@\s*(?<Domain>.+)$' {
                $current.Client = $Matches.Client
                $current.ClientDomain = $Matches.Domain.Trim()
            }

            '^\s*Server:\s*(?<Server>[^\s]+)\s*@\s*(?<Domain>.+)$' {
                $current.Server = $Matches.Server
                $current.ServerDomain = $Matches.Domain.Trim()
            }

            '^\s*KerbTicket Encryption Type:\s*(?<Value>.+)$' {
                $current.EncryptionType = $Matches.Value.Trim()
            }

            '^\s*Ticket Flags\s+(?<Hex>0x[0-9a-fA-F]+)\s*->\s*(?<Flags>.+)$' {
                $current.TicketFlags = $Matches.Flags.Trim()
                $current.TicketFlagsHex = $Matches.Hex
            }

            '^\s*Start Time:\s*(?<Value>.+)$' {
                $current.StartTime = ConvertFrom-KlistDate $Matches.Value
            }

            '^\s*End Time:\s*(?<Value>.+)$' {
                $current.EndTime = ConvertFrom-KlistDate $Matches.Value
            }

            '^\s*Renew Time:\s*(?<Value>.+)$' {
                $current.RenewTime = ConvertFrom-KlistDate $Matches.Value
            }

            '^\s*Session Key Type:\s*(?<Value>.+)$' {
                $current.SessionKeyType = $Matches.Value.Trim()
            }

            '^\s*Cache Flags:\s*(?<Hex>0x[0-9a-fA-F]+)\s*->\s*(?<Flags>.+)$' {
                $current.CacheFlags = $Matches.Flags.Trim()
                $current.CacheFlags = $Matches.Flags.Trim()
                $current.CacheFlagsHex = $Matches.Hex
            }
            

            '^\s*Kdc Called:\s*(?<Value>.+)$' {
                $current.KdcCalled = $Matches.Value.Trim()
            }
        }
    }

    if ($current) {
        $tickets.Add($current)
    }

    $tickets
}

function ConvertFrom-KlistDate {
    param([string]$Value)

    $Value = $Value.Trim()

    # "(local)" entfernen
    $Value = $Value -replace '\s*\(local\)\s*$', ''

    $parsed = [datetime]::MinValue

    foreach ($culture in @(
            [System.Globalization.CultureInfo]::CurrentCulture,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
        )) {
        if ([datetime]::TryParse(
                $Value,
                $culture,
                [System.Globalization.DateTimeStyles]::AllowWhiteSpaces,
                [ref]$parsed
            )) {
            return $parsed
        }
    }

    return $Value
}


#$tickets |
#Where-Object { $_.Server -match 'krbtgt' } |
#Format-List