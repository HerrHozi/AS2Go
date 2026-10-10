function Get-KirbiUniqueAccounts {
    <#
.SYNOPSIS
    Creates a concise summary of unique Kerberos accounts with ticket material.

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


    $uniqueAccounts = $alltickets |                      
    Where-Object { $_.User } |
    Group-Object AccountType, User |
    ForEach-Object {
        [pscustomobject]@{
            AccountType        = $_.Values[0]
            Principal          = $_.Values[1]
            TicketFileCount    = $_.Count
            UniqueSPNCount     = ($_.Group.SPN | Sort-Object -Unique).Count
            UniqueTicketTypes  = ($_.Group.TicketType | Sort-Object -Unique) -join ', '
            TGTCount           = @(
                $_.Group | Where-Object {
                    $_.TicketType -eq 'TGT (krbtgt)'
                }
            ).Count
            ServiceTicketCount = @(
                $_.Group | Where-Object {
                    $_.TicketType -eq 'Service-Ticket'
                }
            ).Count
            LUIDs              = ($_.Group.LUID | Sort-Object -Unique) -join ', '
        }
    } |
    Sort-Object AccountType, Principal

    return $uniqueAccounts

}