# ASP00 Break-Glass Account

Use **BGA** in the public `Initialize-AS2GoLab` setup menu to select the lab's break-glass account. The menu calls the internal `Set-BreakGlassAccount` function; users start the workflow through the public menu.

## Workflow overview

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **BGA**.
    - `Set-BreakGlassAccount` *(internal workflow)*
      - Keep the previously selected account, select a new account, or skip.
      - For a new selection, the AD Object Picker displays the forest tree.
      - Browse through the domain and OUs; select a user account and confirm it.
      - Save the selected account's distinguished name (DN) in the local AS2Go configuration.

The configured account is excluded from AS2Go attack scenarios. This selection does not create an account or change its Active Directory attributes.

## Menu option

```powershell
Initialize-AS2GoLab
```

Complete the setup prompts and select **BGA**. If an account is already configured, choose to keep it, select a replacement, or skip. To select a new account, use the AD Object Picker: expand the forest, browse into the required domain and OU, select the intended user, then confirm the selection.

The picker is opened with `-IncludeUsers`, `-MarkTier0`, and `-BlockOUSelection`. OUs remain available for browsing but cannot be selected; user entries are selectable. A red marker identifies objects matched by the picker's Tier 0 display pattern. It is a visual indicator, not an account validation or authorization check. The picker can display disabled accounts, so confirm that the chosen break-glass account is enabled and appropriate for the lab.

The picker also has a user context menu for enabling or disabling an account and resetting its password. Those actions change Active Directory and are separate from selecting the break-glass account; use them only when intended and authorized.

The shared setup switches and prerequisites are documented in [ASP00 Installation and Setup](ASP00__Setup.md).

## Configuration storage

AS2Go stores its local configuration in:

```text
%PUBLIC%\AS2Go\Config\AS2Go.json
```

The selected account's distinguished name is saved in the `BreakGlassAccount` setting. This setting is written without the `-DPAPI` option, so the DN is stored as readable text in the JSON file. Other individual settings can be protected with machine-scoped Windows DPAPI; this protection does not encrypt the complete configuration file. A setting protected with this method can be decrypted only on the same Windows computer.

The DN identifies the selected directory object; this workflow does not save the account password. Restrict access to the configuration file according to your lab's local security requirements, and review the file before copying it to another computer or sharing it.

## Operational notes

- Selecting **Skip** leaves the current saved value unchanged; it does not clear an existing account.
- Selecting **Previous Break Glass Account** retains the saved DN.
- Selecting **Select new Break Glass Account** replaces the saved DN after the picker returns a selection.
- If the picker is canceled or no account is selected, the current function reports that no account was selected and does not save a new value.
- The picker highlights some Tier 0 entries based on its configured name and OU pattern. It does not verify that the chosen account is dedicated, enabled, monitored, or excluded from every external tool.

## Related documentation

- [ASP00 Installation and Setup](ASP00__Setup.md)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Internal workflow: `Set-BreakGlassAccount`](../Private/Shared/Set-BreakGlassAccount.ps1)
- [AD Object Picker](../Private/Shared/Select-ADObject.ps1)
