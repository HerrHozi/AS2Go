# ASP04 Password Spray Guide | Invoke-ASPhase04BruteForceAttack

*Kill-chain Phase 04, password spraying — test one lab password against every enabled account in a chosen scope and see how far a single weak password plus password-equals-username gets an attacker before the lockout policy stops the run.*

![ASP04 Password Spray phase](../Assets/Images/ASP04.png)

> For explicitly authorized lab environments only. Run from an initialized AS2Go module session.

---

## 1. What this workflow does

[Invoke-ASPhase04BruteForceAttack](../Public/Invoke-Phase04BruteForceAttack.ps1) (alias `ASP04` / `PwSpray`) walks through the password-spray demonstration:

| Step | Action | Details |
|---|---|---|
| 0 | Confirm the phase | Decision prompt; in `-SafeMode` only `Skip` is offered so the phase cannot proceed |
| 1 | Show the policy surface | Forest-wide password-policy table (enabled users, min. length, complexity, lockout threshold/duration/observation window, reversible encryption) with two derived numbers: how many distinct passwords fit under the *minimum* lockout threshold across all domains, and the highest minimum password length |
| 2 | Select the scope | `Set-AttackScope` — current domain (default), forest level, OU level, domain level, or skip |
| 3 | Confirm the spray password | Previous test password offered from the DPAPI-protected `LastPW` setting; a new value must meet the forest-maximum minimum length |
| 4 | Decide the name-as-password fallback | Up to two attempts per account (configured password, then the account's own `samAccountName`) |
| 5 | Spray in parallel | [Start-PasswordSprayAttack](../Private/ASP04/Start-PasswordSprayAttack.ps1) validates credentials with `PrincipalContext.ValidateCredentials` in parallel (throttle 15), with live progress and a `Q` abort |

The phase checks enabled user accounts only; it creates, modifies, and disables no directory objects. Failed attempts still count as real authentication attempts — lockouts and monitoring events are possible outcomes the operator owns.

Start `Start-AS2GoDemo` and select **Brute Force or Password Spray**, then choose the password-spray scenario when prompted.

---

## 2. Why password spraying is the quiet first door

- **One password, many accounts**: brute-force one account and the lockout policy wins; spray many accounts and the policy is silent. The workflow's derived headline — *a maximum of `threshold − 1` password attempts per account* — is the calculation every real attacker runs first. Spraying "Winter2026!" across 10,000 enabled users usually finds accounts before a low lockout threshold fires anywhere.
- **Password-equals-username**: the optional fallback is the cheapest credential attack that exists. It costs no password knowledge and regularly succeeds where organizations skip named-account password policies. In the lab it demonstrates why *"the password is the username"* deserves its own detection rule.
- **The policy table is the attacker's brief and the defender's checklist at once**: enabled-user counts per domain say where scale is; lockout windows and thresholds say how noisy a spray becomes. The demo reads both the way an attacker would — the defender lesson is to know your own numbers before someone else does.

---

## 3. Choose the target scope

The scope menu (`Set-AttackScope`) decides which part of Active Directory the demonstration queries:

| Menu choice | What it includes |
|---|---|
| **Forest Level** | Enabled users across every domain in the forest; processed one domain at a time, each against its own domain controller |
| **Domain Level** | Select a specific domain through the AD Object Picker. The current implementation does not correctly handle the picker result, so this choice may not proceed as expected — use Forest Level or Current Domain until corrected |
| **Current Domain** | Enabled users in the domain of the current session, including child OUs (default) |
| **OU Level** | Enabled users in the selected organizational unit and its child OUs; the previous OU can be reused or replaced |
| **Skip** | Leaves the phase without starting the password checks |

After choosing a scope, review the displayed target and proceed, skip, or change the scope. Forest Level means *all domains in the forest*, not only the current one; an OU limits the account search to that OU's subtree.

---

## 4. Working notes from the lab

### 4.1 The spray engine is not `Invoke-Command` against AD

[Start-PasswordSprayAttack](../Private/ASP04/Start-PasswordSprayAttack.ps1) validates with `System.DirectoryServices.AccountManagement.PrincipalContext.ValidateCredentials(Negotiate)` per account inside a `ForEach-Object -Parallel` pool. Two design details worth quoting in review:

- **One result object per input account, guaranteed**: accounts swallowed by worker exceptions are re-added as `Success = $false` after the job drains, so the report never loses a user to a transient fault.
- **The fallback stays per-account**: option *Yes* tries `Password`, and on failure that account's `SamAccountName` against *the same account* — never cross-account. That keeps the attack pattern honest (a spray, not a permutation attack) and keeps the lockout math linear.

### 4.2 DPAPI protects the stored spray password

The confirmed password is written to `LastPW` with machine-scoped DPAPI (`-DPAPI`), so the next run and the follow-up phases can offer it again without storing plaintext in the configuration file. The prompt still displays the value on screen — treat console, transcripts, and recordings as sensitive.

### 4.3 The lockout math is informational, not enforced

ASP04 computes the forest-minimum lockout threshold and shows the `threshold − 1` spray budget, but the engine does **not** rate-limit or stop at that budget. Unattended runs use the configured values; only the operator decides what is safe for the lab. The same applies to the `Q` abort — already-validated attempts remain counted on the domain controllers.

### 4.4 Progress and abort behave like the disruption executor

The monitor loop polls the parallel job every 250 ms with rate/ETA display and a `Q` abort via `Stop-Job`; completed attempts stay, pending work is dropped. Same operational model as Phase 12's account disruption — one shared pattern across the bulk phases.

---

## 5. What defenders observe (Blue Team notes)

- **Event 4625 bursts with one constant field**: many distinct target accounts, same source host, same (or rotating) submitted password — the inverse of brute force, which hammers one account with many passwords. Detect on `4625` frequency per *source*, then group target-account diversity. MDI flags spray activity before any lockout is visible.
- **Password-equals-username wins invisibly**: a successful spray attempt is a clean `4624` with no prior failures on that account — the account never "alerted" before being owned. Baseline success-vs-failure ratios per source are the detector; a source with `4624` on many never-touched accounts stands out.
- **The lockout threshold is a budget, not a control**: the demo's own arithmetic shows why. A threshold of 5 allows 4 password guesses per account across unlimited accounts. Effective mitigations: smart lockout per source and user, breached-password screening at set time, and monitoring `4625` patterns long before thresholds trip.
- **`samAccountName` fallback success means policy failure**: if the name-as-password option regularly succeeds in a lab mirroring production, named accounts need password-quality rules — not just lockout tuning.
- **The hardening lesson**: lockout policies alone do not stop spraying; they cap the *velocity*. Combine per-source throttling, password-quality gateways (no seasonal or keyboard patterns, no username-derived values), and source-based analytics on `4625`/`4624` pairs.

---

## 6. Command quick reference

```powershell
# The lockout math the workflow shows (derive your own spray budget):
$minLockout = (Get-ADForest).Domains | ForEach-Object { Get-ADDefaultDomainPasswordPolicy -Identity $_ } |
    Measure-Object -Property LockoutThreshold -Minimum | Select-Object -ExpandProperty Minimum
"Spray budget: $($minLockout - 1) distinct passwords per account"

# Spray one password manually against a scope (as Start-PasswordSprayAttack does):
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$ctx = [System.DirectoryServices.AccountManagement.ContextType]::Domain
$opt = [System.DirectoryServices.AccountManagement.ContextOptions]::Negotiate
$pc  = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($ctx, "<DOMAIN-FQDN>")
$pc.ValidateCredentials("<sam>", "<TestPassword>", $opt)   # true = valid

# Defender view — the spray burst on a DC (group by source, count target diversity):
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625 } `
    -MaxEvents 500 -ComputerName <DC-FQDN> |
    Select-Object TimeCreated, Message | Format-List
```

The workflow itself requires no manual commands — run `Invoke-ASPhase04BruteForceAttack` (or `Start-AS2GoDemo` menu option *Brute Force or Password Spray*), confirm scope and password, and choose the fallback option.

---

## 7. Troubleshooting

| Symptom | Likely cause | What to check |
|---|---|---|
| The Active Directory module is reported missing. | RSAT Active Directory tools are unavailable on the host. | Install or enable the module, then start a new PowerShell session. |
| Forest or domain information cannot be retrieved. | No reachable domain controller, or the identity lacks directory read access. | Verify connectivity and access for the selected scope. |
| No accounts are processed. | No enabled users under the selected scope. | Review the confirmed scope; check that enabled users exist there. |
| The new test password is rejected by the prompt. | Blank or shorter than the forest-maximum minimum length. | Enter a non-empty value that meets the displayed length. |
| Accounts lock or the run stops unexpectedly. | Lockout policy reached, `Q` abort, or an environment interruption. | Stop further runs, coordinate with the lab owner, review DC events, reassess scope and policy. |

---

## 8. Related

- Phase diagram: [ASP04.html](../Phases/ASP04.html)
- Parallel spray engine: [Start-PasswordSprayAttack.ps1](../Private/ASP04/Start-PasswordSprayAttack.ps1)
- Scope selection shared across bulk phases: [Set-AttackScope.ps1](../Private/Shared/Set-AttackScope.ps1)
- The follow-up that uses sprayed credentials: ASP05 — Initial Access
- Security policy and authorized use: [SECURITY.md](../SECURITY.md)
- MITRE ATT&CK: Brute Force — Password Spraying [T1110.003](https://attack.mitre.org/techniques/T1110/003/)
