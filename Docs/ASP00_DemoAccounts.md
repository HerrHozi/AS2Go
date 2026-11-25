# ASP00 Demo Accounts

Use **Demo Users** in the public `Initialize-AS2GoLab` menu to create synthetic users from the bundled `AS2Go-DemoUsers.csv` file. The menu calls the private `Invoke-DemoAccounts` workflow; users do not start that private function directly.

## Workflow overview

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **Demo Users**.
    - `Invoke-DemoAccounts` *(internal workflow)*
      - Choose the number of CSV users to create: saved default or a custom count up to **50,000**.
      - Choose the default or another target OU.
      - `New-DemoAccount` creates the selected synthetic users and optional nested OUs.
      - `Add-RandomUsersToAccountOperators` resets the password of a random configured subset and adds those users to **Account Operators**.
      - `Add-CompromisedAccount` creates one separate compromised account in the selected base OU.

The bulk CSV workflow is separate from [`New-AS2GoDemoPrincipalSet`](../Public/New-AS2GoDemoPrincipalSet.ps1), which creates the named lab principals used by AS2Go scenarios.

## OU structure

The default target is `OU=Demo Accounts,OU=AS2Go,<current-domain-DN>`. The `AS2Go` parent name can be changed with `-AS2GoOU` on the public setup command. You can accept this target or select/create another OU in the current domain.

- `OU=AS2Go` *(or the configured `-AS2GoOU` name)*
  - `OU=Demo Accounts` *(default target)*
    - **Default:** create users directly in this OU.
    - **By department:** create users in `OU=<Department>,OU=Demo Accounts,...`.
    - **By country:** create users in `OU=<CountryCode>,OU=Demo Accounts,...`.
    - **By country and department:** create users in `OU=<Department>,OU=<CountryCode>,OU=Demo Accounts,...`.

If you select another target OU, the selected target replaces `OU=Demo Accounts` as the base for these optional nested OUs. The separately created compromised account is placed in the selected base OU, not in a country or department sub-OU.

The default path is constructed under the current domain root from `-AS2GoOU`; it does not reuse the parent OU selected earlier in **AS2Go Assets**. If that Assets OU was created under a custom parent, the default **Demo Users** path may create a second `AS2Go\Demo Accounts` branch under the domain root. Select the intended target OU explicitly in that case.

## Before you begin

Complete the shared installation, authorization, and setup guidance in [ASP00 Installation and Setup](ASP00-Setup.md). Run the menu from the elevated Enterprise Admin setup session on the prepared, domain-joined Windows Server. The public initializer checks elevation and Domain Admins or Enterprise Admins membership; the setup screen recommends Enterprise Admin privileges for full configuration.

The workflow requires the Active Directory management tools, access to the current domain, and rights to create users and OUs and update group membership and account passwords. It uses the configured `AS2Go-DemoUsers.csv` file under the module's `LabSetup` directory. The bundled file contains **50,000 data rows**, which sets the current maximum selectable number of bulk demo users.

## Menu option

```powershell
Initialize-AS2GoLab
```

After the prerequisite checks, select **Demo Users** in the setup menu. `Setup-AS2GoDemo` and `ASP00` are aliases of `Initialize-AS2GoLab`. The setup command's shared switches are documented in [ASP00 Installation and Setup](ASP00-Setup.md#shared-command-switches).

## Parameters

There is no public parameter for the demo-user count or target OU. The workflow prompts for both. These public setup parameters affect the resulting OU path or user metadata:

| Parameter | Default | Effect |
|---|---|---|
| `-AS2GoOU` | `AS2Go` | Names the parent OU used to form the default `Demo Accounts` target. |
| `-Scenario` | `AS2Go` | Labels created objects and contributes to the display names of bulk demo users. The value cannot contain whitespace. |

The count prompt defaults to the saved `LastNumofDemoUsers` setting; the bundled configuration starts at **1,000**. A custom value must be an integer from 1 through the number of rows currently in the CSV. If the saved default is higher than the CSV row count, the workflow reduces it for that run.

## Output

The workflow writes progress to the console and does not define a dedicated result object. It reports progress for the parallel account-creation job and displays a completion count. The helper uses up to **35 parallel workers**; press **Q** to stop that bulk job.

The CSV rows are randomly selected. Each bulk user receives synthetic identity and contact attributes from the CSV, a randomly assigned department and title, and an enabled account with `PasswordNeverExpires` set. The password is derived from the CSV password value with the fixed suffix `!2xY`. A UPN suffix is selected interactively by keeping the saved suffix or choosing a new one.

After bulk creation, the workflow selects users from the entire target OU subtree, not only the users created in the current run. By default, the bundled `RandomAccountOperators` setting selects **10** users, resets their passwords to the shared lab password, enables them, and adds them to the built-in **Account Operators** group. The workflow then creates one separate enabled compromised account in the base target OU, using the shared lab password and setting `PasswordNeverExpires`.

Objects created by the workflow are tagged with the selected scenario and the ASP00 creation marker so the public `Remove-AS2GoLab -DemoUser` workflow can discover the bulk demo users.

## Required permissions

`Initialize-AS2GoLab` checks that the process is elevated and that the current account belongs to Domain Admins or Enterprise Admins. Creating the users and OUs and applying the Account Operators membership and password changes requires corresponding rights in the current domain. Use the Enterprise Admin setup session for this lab workflow and verify rights on any custom target OU.

## Safety and operational impact

- **Directory changes:** Creates up to 50,000 bulk fake users, optional country/department OUs, and one additional compromised account. The total is therefore up to 50,001 new user accounts if all operations succeed.
- **Account Operators:** The random selection searches all users under the selected base OU. If that OU already contains unrelated accounts, they may be selected, enabled, have their passwords reset, and be added to Account Operators. Use a dedicated lab OU.
- **Passwords:** Bulk passwords are derived from the bundled CSV values. The selected Account Operators users and the compromised account use the shared lab password. Treat all generated accounts as lab-only credentials.
- **Cancel behavior:** Selecting **Skip** at the user-count prompt returns without creating accounts. Pressing **Q** during the parallel job stops that job, but the parent workflow then continues to the Account Operators and compromised-account steps.
- **OU prompt behavior:** The OU prompt offers **Skip**, but the current implementation does not return on that selection; it falls through to the default OU. Confirm the displayed target before continuing.
- **Preview:** `Initialize-AS2GoLab -Preview` returns before opening the setup menu and does not preview the exact user or OU changes. The **Demo Users** menu action has no `-WhatIf` or dry-run control.
- **Group membership:** The compromised-account helper checks for `SG-AS2Go-Victims`. The AS2Go Assets workflow creates `SG-AS2Go-Users` by default, so the compromised account may be created without a group membership and a warning may be displayed unless `SG-AS2Go-Victims` exists.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| The count prompt rejects a value. | The value is not a positive integer or exceeds the current CSV row count. | Enter an integer from 1 through the maximum shown in the prompt; the bundled CSV currently has 50,000 rows. |
| The default count is lower than expected. | `LastNumofDemoUsers` is saved locally or was reduced because the CSV has fewer rows. | Enter a custom count within the available CSV rows, or review the saved setting and CSV file. |
| Demo users are created in an unexpected OU. | The selected target or nested OU layout differs from the default. | Review the target OU and layout prompts; use a dedicated lab OU and verify `AS2GoSearchBase` afterward. |
| Existing accounts are unexpectedly in Account Operators or have a changed password. | The selected base OU contained existing users; the random selection searches the whole subtree. | Review the selected OU and group membership. Use a dedicated lab OU and restore affected lab account passwords and memberships. |
| The compromised account is created without expected membership. | `SG-AS2Go-Victims` is absent; the default assets workflow creates `SG-AS2Go-Users` instead. | Review the warning and verify the intended group name and membership in the lab. |
| The displayed success count does not match the directory. | The parallel job suppresses per-user nonterminating `New-ADUser` errors before counting its job results. | Verify created users with `Get-ADUser` in the selected OU and check the AS2Go log and domain-controller events. |

## Related documentation

- [ASP00 Installation and Setup](ASP00-Setup.md)
- [ASP00 AS2Go Assets](ASP00_AS2GoAssets.md)
- [Security Policy and authorized use](../SECURITY.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Public cleanup function: `Remove-AS2GoLab`](../Public/Remove-AS2GoLab.ps1)
- [Bundled fake-user CSV](../LabSetup/AS2Go-DemoUsers.csv)
