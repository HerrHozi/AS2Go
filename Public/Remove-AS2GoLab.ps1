<#
.SYNOPSIS
Removes AS2Go lab objects and configuration created by Initialize-AS2GoLab.

.DESCRIPTION
The Remove-AS2GoLab function reverts what Initialize-AS2GoLab and its sub-functions created,
selected by category through the switch parameters below. Discovery combines the AS2Go
configuration file with the adminDescription tag (AS2Go|Scenario|ASP00|Create) written by the
create functions, so only AS2Go-created objects are affected.

-All runs every category in the order required for a clean removal: local Administrators
membership, AD group nesting, moving the built-in Domain Admins/Enterprise Admins groups back to
CN=Users, restoring the Tier 0 ACL, demo users, the named demo principal set (including the local
user profile on this machine and the SPN computer), the AS2Go security groups, the AS2Go OU
structure, the backup share, the AD CS templates and Certification Authority, and finally the
local $env:PUBLIC\AS2Go folder (last, because the earlier steps still need its configuration file).

Each category prompts for confirmation before deleting anything and is idempotent: a missing
object is reported as a warning rather than treated as an error.

.PARAMETER DemoUser
Removes the randomly generated demo users created by Invoke-DemoAccounts.

.PARAMETER DemoPrincipalSet
Removes the named lab principals and the compromised account created by
New-AS2GoDemoPrincipalSet/Add-CompromisedAccount, their SPN computer, and the local user profile
left on this machine.

.PARAMETER Groups
Reverts local and AD group nesting, moves the built-in privileged groups back to CN=Users,
restores the Tier 0 ACL, and deletes the AS2Go security groups.

.PARAMETER AS2GoOU
Removes the AS2Go tiered OU structure.

.PARAMETER Share
Removes the AD-Backup SMB share and its folder from the configured server.

.PARAMETER ADCS
Removes the AS2Go certificate templates and decommissions the AS2GoRootCA.

.PARAMETER AS2GoFolder
Removes the complete local $env:PUBLIC\AS2Go folder, including the configuration file. Always
runs last.

.PARAMETER All
Runs every removal category above, in the required order.

.PARAMETER Scenario
Scenario label used to match the adminDescription tag written at creation. Defaults to AS2Go.

.PARAMETER Server
Domain controller used for Active Directory operations. Defaults to the current logon server.

.PARAMETER Preview
Shows a preview of this function instead of running it.

.EXAMPLE
Remove-AS2GoLab -DemoUser -DemoPrincipalSet

Description: Removes only the demo users and the named demo principal set.

.EXAMPLE
Remove-AS2GoLab -All

Description: Removes every AS2Go lab object and configuration created by Initialize-AS2GoLab, in
the required order.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
None. The function performs removal operations and reports progress through console messages.

.NOTES
Author: AS2Go Team

Prerequisites:
- The function requires elevated privileges (Domain Admin equivalent).
- The ActiveDirectory PowerShell module must be installed.
- Run from the same machine Initialize-AS2GoLab was run from when using -DemoPrincipalSet, so the
  local user profile cleanup targets the correct machine.

Always assumes a freshly tagged AS2Go lab. Environments created before this tagging scheme was
introduced should first be migrated with Update-AS2GoLabAttribute.

Related Functions:
- Initialize-AS2GoLab
- Update-AS2GoLabAttribute
- Remove-AS2GoDemoAccounts
- Remove-AS2GoGroups
- Remove-AS2GoOU
- Remove-BackUpShare
- Remove-ADCSForAS2Go
- Remove-AS2GoFolder

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Removes AS2Go demo accounts, security groups, OU structure, backup share, AD CS templates/CA, and
the local AS2Go data folder, selected by switch and discovered through the ASP00 creation tag.
#>
function Remove-AS2GoLab {

    [Alias("Uninstall-AS2GoLab")]
    param(
        [switch]$Preview,
        [switch]$DemoUser,
        [switch]$DemoPrincipalSet,
        [switch]$Groups,
        [switch]$AS2GoOU,
        [switch]$Share,
        [switch]$ADCS,
        [switch]$AS2GoFolder,
        [switch]$All,
        [string] $Scenario = "AS2Go",
        [string] $Server
    )

    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Remove-AS2GoLab' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

    $result = Test-LocalAdministrator
    if (-not $result.IsElevated) {
        Write-AS2GoOutput -Type Error -Message "This function must be run as Administrator."
        return
    }

    $info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $info.FunctionName

    if (-not $DemoUser -and -not $DemoPrincipalSet -and -not $Groups -and -not $AS2GoOU -and -not $Share -and -not $ADCS -and -not $AS2GoFolder -and -not $All) {
        Write-AS2GoOutput -Type Warning -Message "No removal category was selected. Use -All or one of the category switches (see Get-Help Remove-AS2GoLab)."
        Measure-FunctionRuntime -End -Details $info
        return
    }

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Remove AS2Go Lab Setup"
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality

    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = $Script:LogonServer
    }
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Get-LogonServerFQDN
    }

    if ($All) {
        $SelectedCategories = "All (every category)"
    }
    else {
        $SelectedCategories = @(
            if ($DemoUser) { "DemoUser" }
            if ($DemoPrincipalSet) { "DemoPrincipalSet" }
            if ($Groups) { "Groups" }
            if ($AS2GoOU) { "AS2GoOU" }
            if ($Share) { "Share" }
            if ($ADCS) { "ADCS" }
            if ($AS2GoFolder) { "AS2GoFolder" }
        ) -join ", "
    }

    Write-AS2GoOutput -Type Bullet -Message "Scenario:       " -Tm $Scenario
    Write-AS2GoOutput -Type Bullet -Message "Target Server:  " -Tm $Server
    Write-AS2GoOutput -Type Bullet -Message "Switches:       " -Tm $SelectedCategories

    $title = "Confirm the removal scope"
    $message = "This removes AS2Go objects and configuration from Active Directory and this machine. This cannot be undone. Proceed?"
    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Proceed with the selected removal categories."; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&Quit"; Help = "Abort without removing anything."; Value = $Script:No }
    )
    $answer = Show-DecisionPrompt -Title $title -Message $message -Default 1 -Options $Options

    if ($answer -ne $Script:Yes) {
        Write-Log -Message "User chose to quit Remove-AS2GoLab. Exiting..."
        Measure-FunctionRuntime -End -Details $info
        return
    }

    try {

        if ($All) {
            # -All interleaves Groups: the nesting/local-admin/move-back/ACL revert runs first (demo
            # accounts may still be members), the group deletion itself runs after demo accounts are gone.
            Remove-AS2GoGroups -Scenario $Scenario -Server $Server -RevertNestingOnly
        }
        elseif ($Groups) {
            Remove-AS2GoGroups -Scenario $Scenario -Server $Server
        }

        if ($All -or $DemoUser) {
            Remove-AS2GoDemoAccounts -DemoUser -Scenario $Scenario -Server $Server
        }

        if ($All -or $DemoPrincipalSet) {
            Remove-AS2GoDemoAccounts -DemoPrincipalSet -Scenario $Scenario -Server $Server
        }

        if ($All) {
            Remove-AS2GoGroups -Scenario $Scenario -Server $Server -DeleteGroupsOnly
        }

        if ($All -or $AS2GoOU) {
            Remove-AS2GoOU -Scenario $Scenario -Server $Server
        }

        if ($All -or $Share) {
            Remove-BackUpShare
        }

        if ($All -or $ADCS) {
            Remove-ADCSForAS2Go -CTPrefix $Scenario
        }

        if ($All -or $AS2GoFolder) {
            # Always last: the earlier steps above still rely on the AS2Go configuration file.
            Remove-AS2GoFolder
        }
    }
    catch {
        Write-AS2GoOutput -Type Error -Message "Remove-AS2GoLab stopped unexpectedly: $_"
    }

    Write-AS2GoOutput -Type Success -Message "Finished the AS2Go removal run."
    Measure-FunctionRuntime -End -Details $info
}
