function Get-KirbiUniqueInfo {
    <#
.SYNOPSIS
    Creates a concise Kerberos ticket findings summary.

.DESCRIPTION
    Generates a report-ready summary based on exported Kerberos ticket metadata.

    The summary includes:
    - Total number of exported ticket files
    - Number of unique ticket records after deduplication
    - Number of user accounts with ticket material
    - Number of computer accounts with ticket material
    - Number of unique tickets assessed as potentially relevant to
      Pass-the-Ticket (PtT) activity

    PtT-relevant tickets include:
    - TGTs, identified by a krbtgt target SPN
    - Service Tickets, identified by a concrete service target SPN

    Type 1 / special logon-cache records are counted only when their SPN is a
    concrete service SPN. Unknown filename formats are excluded.

.NOTES
    Prerequisites:
    $alltickets    = Get-KirbiTicketInfo -Path '<PathToKirbiFiles>'
    $uniqueTickets = Deduplicated ticket data, grouped by account, ticket type,
                     type number, and target SPN.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]] $alltickets
    )

    if (-not $alltickets) {
        throw 'No ticket data found. Populate $alltickets before creating the summary.'
    }

    # Create a unique view if it was not created previously.
    if (-not $uniqueTickets) {
        $uniqueTickets = $alltickets |
        Where-Object { $_.User -and $_.SPN } |
        Group-Object AccountType, User, TicketType, Type, SPN |
        ForEach-Object {
            [pscustomobject]@{
                AccountType = $_.Values[0]
                User        = $_.Values[1]
                TicketType  = $_.Values[2]
                Type        = [int] $_.Values[3]
                SPN         = $_.Values[4]
                Count       = $_.Count
                LUIDs       = ($_.Group.LUID | Sort-Object -Unique) -join ', '
                FirstSeen   = $_.Group.LastWrite | Sort-Object | Select-Object -First 1
                LastSeen    = $_.Group.LastWrite | Sort-Object -Descending | Select-Object -First 1
            }
        }
    }

    # Count all exported .kirbi files.
    $exportedTicketFileCount = @($alltickets).Count

    # Count deduplicated ticket records.
    $uniqueTicketCount = @($uniqueTickets).Count

    # Count distinct accounts by account category.
    $userAccountCount = @(
        $uniqueTickets |
        Where-Object { $_.AccountType -eq 'User' } |
        Select-Object -ExpandProperty User -Unique
    ).Count

    $computerAccountCount = @(
        $uniqueTickets |
        Where-Object { $_.AccountType -eq 'Computer' } |
        Select-Object -ExpandProperty User -Unique
    ).Count

    # A TGT is identified by the krbtgt target.
    # A service ticket is identified by a non-empty target SPN that is not krbtgt.
    # "Unknown format" records are intentionally excluded.
    $pttRelevantTickets = @(
        $uniqueTickets |
        Where-Object {
            $_.TicketType -ne 'Unbekanntes Format' -and
            $_.SPN -and
            (
                $_.SPN -match '(?i)^krbtgt[-/]' -or
                $_.TicketType -eq 'Service-Ticket' -or
                (
                    $_.TicketType -eq 'Spezial/Logon-Ticket' -and
                    $_.SPN -notmatch '(?i)^krbtgt[-/]'
                )
            )
        }
    )

    $pttRelevantTicketCount = $pttRelevantTickets.Count

    # Report-ready text.
    $findingsSummary = @"
The analysis identified the following Kerberos ticket findings:

- $exportedTicketFileCount exported ticket files were identified.
- $uniqueTicketCount unique Kerberos ticket records were identified after deduplication.
- $userAccountCount user accounts had Kerberos ticket material present.
- $computerAccountCount computer accounts had Kerberos ticket material present.
- $pttRelevantTicketCount unique ticket records were assessed as potentially relevant to Pass-the-Ticket (PtT) activity.

PtT relevance includes Ticket Granting Tickets (TGTs), which may be used to
request additional service tickets within the associated account's permissions,
and service tickets, which may be usable for their respective target
service/SPN. Actual usability depends on ticket validity, session-key
availability, account permissions, and target-service configuration.
"@

    $findingsSummary
}