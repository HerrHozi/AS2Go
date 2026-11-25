# Find-ADForestUser Guide | Targeted Password Search and Named-Account Spray

*Kill-chain companion to Phase 04 — find AD accounts by a sign-in-name substring across the entire forest, optionally with a targeted password test per found account. Where the password-spray demo is broad (one password × every account), this is the narrow counterpart: one name fragment × every domain, then optional credential checks on the shortlist.*

> For explicitly authorized lab environments only. Requires the ActiveDirectory PowerShell module.

---

## 1. What this workflow does

[Find-ADForestUser](../Public/Find-ADForestUser.ps1) (Public cmdlet, usable outside the demo menu):

| Step | Action | Details |
|---|---|---|
| 0 | Build an escaped LDAP filter | Literal-substring match on `sAMAccountName` — special characters (`\`, `*`, `(`, `)`, NUL) are RFC-4515-escaped, so what you type is what is matched |
| 1 | Search per domain | Runs the filter in **every domain of the current forest**; an unreachable domain is reported as a warning and skipped, the rest continue |
| 2 | Resolve context | NetBIOS name per domain (warning + empty field when it fails); with a password supplied, the preferred domain controller via `Get-BestDomainController` |
| 3 | Optional credential check | For every **enabled** match: `Test-ADLogon` with the supplied password against the domain's DC; disabled matches are counted and skipped |
| 4 | Enrich and report | Every match carries its DN, UPN, and **transitive group membership with RIDs** (`member:1.2.840.113556.1.4.1941:=` LDAP_IN_CHAIN) — sorted by RID; matches with accepted passwords are highlighted at the end |

Typical uses: reconnaissance of similarly-named accounts (`-User 'as2go'` finds `As2go`, `AS2Go.h`, `h.as2go`, …) plus the targeted "**did any of these use my test password?**" question — the directed single-user counterpart to the forest-wide [ASP04 Password Spray](ASP04_Password-Spray.md).

---

## 2. Why a targeted variant matters

- **Spray volume draws detection; precision does not**: a forest-wide spray touches thousands of accounts and is the loudest event in the kill chain. Searching for a *name pattern* first, then testing passwords only on the shortlist, produces a fraction of the logon attempts with the same information gain — exactly how real attackers avoid lockouts while still finding the right account.
- **Account naming reconnaissance is its own step**: finding `As2go`, `AS2Go.h`, and `h.as2go.h` in one query reveals the lab's naming convention — which feeds guessing strategies for later phases. The substring approach (not exact-match) is what makes this enumeration useful.
- **Group membership answers "is this account worth cracking?"** in the same query: the transitive `MemberOf`/RID list (512, 519, 548 …) appears immediately next to the match — no second pass needed. Operators see at a glance which found account is Tier-0.
- **The security lesson in one line**: an attack that looks like account discovery (a single LDAP query) plus a *few* credential checks is far harder to detect than a spray — the detector pair (directory-read patterns + low-volume logon checks against one fragment) is what the demo trains.

---

## 3. Parameters

| Parameter | Effect |
|---|---|
| `-User <fragment>` (mandatory) | Literal substring searched inside `sAMAccountName`, case-insensitive, RFC-4515-escaped |
| `-Password <plain>` | Optional; switches on per-enabled-match credential checks via `Test-ADLogon` — **failed checks count as real logon attempts** (lockout counters advance) |

The password test runs only against enabled accounts; disabled ones are counted (`Skipped password checks for N disabled account(s)`) rather than tested, respecting the same enabled-only policy as the spray workflow.

---

## 4. Working notes from the lab

### 4.1 The escape routine makes user input safe

`$User.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29')` (+ NUL) converts arbitrary input into an RFC-4515-safe LDAP filter fragment. Without it, a `*` or `(` in `-User` would change the filter's meaning (or break it) — the small function that makes a public cmdlet safe to script against.

### 4.2 Transitive membership via LDAP_IN_CHAIN

Group enrichment uses the control OID `(member:1.2.840.113556.1.4.1941:=<DN>)` — the *transitive* member-of query. Direct memberships and nested chains both appear, so a demo account nested in a Tier-0 group reports the Tier-0 RID even though `memberOf` alone would not. RIDs are sorted; the joined lists (`MemberOf`, `MemberOfRid`) keep the two aligned.

### 4.3 Password checks resolve a preferred DC per domain

With `-Password`, each domain asks `Get-BestDomainController` for its preferred DC; credential checks against that DC avoid scattered random-DC logons and keep the generated 4768/4769 events attributable to one server per domain — a detail that matters both in demos and in real-world audit correlation.

### 4.4 Domain outages degrade gracefully

Two failure modes are handled separately per domain: an unreachable search target is skipped with a warning (search continues in other domains), and a failed NetBIOS lookup leaves matches with an empty `NetBIOSName` (they are still reported, display falls back to `DOMAIN-FQDN\user`). A forest sweep never dies on one dead DC.

### 4.5 The result summary distinguishes matched accounts from disabled skips

After the loop: matched accounts are listed with their `NETBIOS\name` (or FQDN fallback), and the count of skipped disabled accounts is reported separately — so an operator knows both "who used the password" and "who was not checked because disabled."

---

## 5. What defenders observe (Blue Team notes)

- **The enumeration is a directory-read, not a logon event**: the substring search is an LDAP query against each domain — visible to directory-audit pipelines (Event 1644 with an expensive/innefficient-search policy, or Sysmon for network directory access) but *not* as logon failures. This is the reason credential-check volume is the better detector than spray volume: low-volume checks against a curated account list are the modern attacker shape.
- **Credential checks against curated accounts**: the `Test-ADLogon` attempts produce 4768/4766 (pre-auth + failure) pairs for the *shortlist's* accounts only — a few failures spread across domains. The detector is the pattern (one source, one password, several distinct accounts, all sharing a naming pattern), not volume.
- **The LDAP filter itself is an indicator**: `(sAMAccountName=*fragment*)` with a common product/project substring is a recon fingerprint. Directory-audit policies that log inefficient searches (Event 1644 thresholds) or enumerate-LDAP-source analytics catch repeated substring sweeps.
- **Cross-domain enumeration indicates credential-adjacent intent**: a single identity querying every domain's directory in one run is reconnaissance, not casual administration. The module's cross-domain loops (this function, the spray, the disruption) all share this shape — a source-domain baseline per identity flags it.
- **The hardening ladder**: least-privilege directory reads (this query needs only domain-user rights — audit who *can* enumerate), directory-search auditing (1644/high-threshold eventing), lockout/bad-password counter monitoring paired with naming-pattern analytics, and — structurally — no shared naming conventions for privileged accounts (`As2go`, `As2go.h` naming patterns are exactly what a fragment sweep feeds on).

---

## 6. Command quick reference

```powershell
# 1) Recon only — find account-name patterns across the forest:
Find-ADForestUser -User 'as2go'

# 2) Recon + targeted credential test (real logon attempts - lockout counters advance):
Find-ADForestUser -User 'as2go' -Password 'Hozi-Lab!42'

# 3) The report shape the demo uses:
Find-ADForestUser -User 'as2go' -Password 'Hozi-Lab!42' |
    Select-Object NetBIOSName, SamAccountName, Enabled, MemberOfRid, PasswordMatched |
    Format-Table -AutoSize

# 4) Defender view — low-volume credential checks against a curated list:
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4768, 4771 } `
    -MaxEvents 200 -ComputerName <DC-FQDN> |
    Group-Object { $_.Properties[0].Value } |        # target account
    Sort-Object Count -Descending | Select-Object Count, Name | Format-Table
```

---

## 7. Related

- The broad counterpart (one password × forest): [ASP04 Password Spray guide](ASP04_Password-Spray.md)
- The targeted logon check used per account: [Test-ADLogon.ps1](../Private/Shared/Test-ADLogon.ps1)
- Preferred-DC resolution used per domain: [Set-BestDomainController.ps1](../Private/Shared/Set-BestDomainController.ps1)
- MITRE ATT&CK: Account Discovery — Domain Account [T1087.002](https://attack.mitre.org/techniques/T1087/002/), Password Guessing [T1110.001](https://attack.mitre.org/techniques/T1110/001/)
