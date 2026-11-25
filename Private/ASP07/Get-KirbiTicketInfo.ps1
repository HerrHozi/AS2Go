function Get-KirbiTicketInfo {

<#
.SYNOPSIS
    Reads exported Kerberos ticket files (.kirbi) from a directory and
    presents their filename-derived metadata in a structured format.

.DESCRIPTION
    The function parses the names of exported .kirbi files and extracts,
    where the filename matches the expected format:

    - User or computer account
    - Account type: User or Computer
    - Logon ID (LUID)
    - Ticket cache/export type
    - Ticket index and ticket flags
    - Target service / SPN
    - File size and last modification time

    Computer accounts are identified by a trailing dollar sign ($), such as
    "SERVER01$". All other accounts are classified as user accounts.

    Ticket types:
    - Type 0: Service Ticket. Intended for a specific Kerberos service or SPN,
      for example CIFS, LDAP, HTTP, GC, or MSSQLSvc.
    - Type 1: Additional ticket or logon-cache context. Its exact meaning
      should not be inferred from the type number alone; the SPN and ticket
      contents are authoritative.
    - Type 2: Ticket Granting Ticket (TGT). Usually also identifiable by a
      target such as "krbtgt-<domain>". A TGT can be used with the KDC to
      request additional service tickets for services the account is permitted
      to access.

    Pass-the-Ticket relevance:
    - TGTs are particularly relevant because they can be used to request
      service tickets for multiple Kerberos services, subject to the account's
      existing permissions.
    - Service tickets are also relevant, but are limited to the specific target
      service/SPN, for example CIFS on a particular server.
    - The security impact must be assessed in context: account privileges,
      target system, ticket validity, and the target SPN are all important.

    This function classifies files based on their filename only. It does not
    validate ticket signatures, lifetimes, encryption types, PAC contents, or
    authorization data. For a complete forensic assessment, inspect the ticket
    contents and correlate them with relevant Kerberos and Windows log events.

.PARAMETER Path
    Local or UNC path to the directory containing .kirbi files.

.EXAMPLE
    Get-KirbiTicketInfo -Path 'C:\Temp\tickets' |
        Format-Table User, AccountType, TicketType, Type, SPN, LUID -AutoSize

    Reads all .kirbi files from the directory and displays a concise overview
    of the ticket metadata.

.EXAMPLE
    Get-KirbiTicketInfo -Path '\\Server01\Temp\tickets' |
        Where-Object { $_.TicketType -eq 'TGT (krbtgt)' -and $_.AccountType -eq 'User' } |
        Format-Table User, LUID, SPN -AutoSize

    Displays TGT files for user accounts. This can be an initial prioritization
    view during an authorized security assessment or incident response.

.NOTES
    The function expects the following filename format:

    [0;<LUID>]-<Type>-<Index>-<Flags>-<Account>@<SPN>.kirbi

    The export/cache type number is not a replacement for full Kerberos ticket
    analysis. For reliable classification, inspect the target SPN:
    "krbtgt-..." represents a TGT, whereas concrete services such as
    "cifs-...", "ldap-...", or "HTTP-..." represent service tickets.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    write-log INFO "Get-KirbiTicketInfo >> Starting to process .kirbi files in path: $Path"
    # Muster:
    # [0;<LUID>]-<Type>-<Index>-<Flags>-<User>@<SPN>.kirbi
    $pattern = '^\[0;(?<LUID>[0-9a-fA-F]+)\]-(?<Type>\d)-(?<Index>\d)-(?<Flags>[0-9a-fA-F]+)-(?<User>[^@]+)@(?<SPN>.+)\.kirbi$'

    Get-ChildItem -Path $Path -Filter *.kirbi -File | ForEach-Object {
        $name = $_.Name


        if ($name -match $pattern) {
            $luid  = $matches['LUID']
            $type  = [int]$matches['Type']
            $index = [int]$matches['Index']
            $flags = $matches['Flags']
            $user  = $matches['User']
            $spn   = $matches['SPN']

            # Ticket-Typ einordnen
            switch ($type) {
                0 { $ticketType = 'Service-Ticket' }
                1 { $ticketType = 'Spezial/Logon-Ticket' }
                2 { $ticketType = 'TGT (krbtgt)' }
                default { $ticketType = "Unbekannt ($type)" }
            }

            # Account-Typ: Computer vs. User
            if ($user -like '*$') {
                $accountType = 'Computer'
            }
            else {
                $accountType = 'User'
            }

            [pscustomobject]@{
                FileName   = $name
                LUID       = $luid
                Type       = $type
                TicketType = $ticketType
                Index      = $index
                Flags      = $flags
                User       = $user
                AccountType= $accountType
                SPN        = $spn
                Length     = $_.Length
                LastWrite  = $_.LastWriteTime
                Path = $_.FullName
            }
        }
        else {
            # Datei passt nicht ins erwartete Muster
            [pscustomobject]@{
                FileName   = $name
                LUID       = $null
                Type       = $null
                TicketType = 'Unbekanntes Format'
                Index      = $null
                Flags      = $null
                User       = $null
                AccountType= $null
                SPN        = $null
                Length     = $_.Length
                LastWrite  = $_.LastWriteTime
                Path       = $_.FullName
            }
        }
    }
}