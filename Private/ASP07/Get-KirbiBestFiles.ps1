function Get-KirbiBestFiles {
    <#
    .SYNOPSIS
    Selects ticket records and matching ticket pairs for a candidate account.

    .DESCRIPTION
    Filters ticket data for the specified candidate and groups matching TGT and
    service-ticket records by logon ID (LUID).

    .PARAMETER alltickets
    Ticket records containing user, LUID, ticket type, SPN, file name, and path data.

    .PARAMETER candidate
    Account name used to filter the ticket records.

    .OUTPUTS
    A custom object containing CandidateTickets and TicketPairs.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]] $alltickets,
        [Parameter(Mandatory = $true)]
        [string] $candidate
    )

    if (-not $alltickets) {
        throw 'No ticket data found. Populate $alltickets before creating the summary.'
    }

    $candidateTickets = $alltickets |
    Where-Object {
        $_.User -eq $candidate -and
        $_.LUID -and
        $_.SPN
    } |
    Group-Object User, LUID, TicketType, Type, SPN |
    ForEach-Object {
        $_.Group | Select-Object -First 1
    }

    $ticketPairs = foreach ($luidGroup in ($candidateTickets | Group-Object LUID)) {
        $tgt = $luidGroup.Group |
        Where-Object {
            $_.TicketType -eq 'TGT (krbtgt)'
        } |
        Select-Object -First 1

        $serviceTicket = $luidGroup.Group |
        Where-Object {
            $_.TicketType -eq 'Service-Ticket'
        } |
        Sort-Object SPN |
        Select-Object -First 1

        if ($tgt -and $serviceTicket) {
            [pscustomobject]@{
                LUID        = $luidGroup.Name
                TGTFile     = $tgt.FileName
                TGTSPN      = $tgt.SPN
                ServiceFile = $serviceTicket.FileName
                ServiceSPN  = $serviceTicket.SPN
                Account     = $candidate
                Path        = $tgt.Path
            }
        }
    }

    return [pscustomobject]@{
        TicketPairs      = @($ticketPairs)
        CandidateTickets = @($candidateTickets)
    }

}