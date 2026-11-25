function Select-ADObject {
    <#
    .SYNOPSIS
        Displays an interactive GUI dialog to select an Active Directory object from the forest hierarchy,
        uses System.DirectoryServices (LDAP/ADSI).

    .DESCRIPTION
        Select-ADObject provides a graphical user interface (GUI) for browsing and selecting Active Directory 
        objects such as Organizational Units (OUs), users, groups, and computers. The function displays a 
        tree view of the forest structure with custom icons for different object types. It supports browsing
        across multiple domains and optionally highlights Tier 0 (high-security) objects.
        Disabled user and computer accounts are shown with a small red cross in the bottom-right corner
        of their icon. Tier 0 objects are marked with a red dot in the top-right corner.
        Right-click a user to enable or disable the account or to reset its password (optionally forcing
        a password change at next logon).
        Selection of OUs and containers can be blocked (-BlockOUSelection) so that only other object types
        can be picked while OUs remain browsable.

    .COMPONENT
    Category: Sub Function

    .FUNCTIONALITY
    Browses forest objects in a GUI, supports OU creation, user enable/disable and password reset, optionally blocks OU selection, and highlights Tier 0 entries and disabled accounts.

    .PARAMETER Title
        The text displayed in the dialog window title. Default is "Select AD Object".

    .PARAMETER DomainController
        Optional DNS name of a domain controller used to discover the forest and access its own domain.
        Other forest domains use automatic controller selection. With LocalDomainOnly, only the supplied
        controller's domain is shown. Omit this parameter to retain automatic discovery.

    .PARAMETER LocalDomainOnly
        If specified, only the current domain (or the supplied controller's domain) is displayed. By default, all domains
        in the forest are shown.

    .PARAMETER DomainSelectionOnly
        If specified, only domain objects can be selected. The tree view is not expanded to show child objects.

    .PARAMETER AddOU
        Enables a context menu for creating an organizational unit under a selected domain, OU, or container.

    .PARAMETER BlockOUSelection
        If specified, organizational units and containers can still be browsed (expanded) but cannot be
        selected, so the OK button stays disabled for them. Intended for use with -IncludeUsers,
        -IncludeGroups, -IncludeComputers or -IncludeGPOs, so that only those object types can be picked.

    .PARAMETER IncludeGPOs
        If specified, GPO objects (groupPolicyContainer) are included in the browsable tree view.

    .PARAMETER ShowAdvanced
        If specified, objects flagged with showInAdvancedViewOnly are shown as well.

    .PARAMETER IncludeLinkedGPOs
        Displays GPOs linked to each domain, OU, or container as selectable child entries.

    .PARAMETER IncludeUsers
        If specified, user objects are included in the browsable tree view.

    .PARAMETER IncludeGroups
        If specified, group objects are included in the browsable tree view.

    .PARAMETER IncludeComputers
        If specified, computer objects are included in the browsable tree view.

    .PARAMETER MarkTier0
        If specified, Tier 0 (high-security) objects are marked with a red dot in the top-right corner
        of their icons. This helps identify highly sensitive AD objects. Can be combined with the red
        cross shown for disabled accounts.

    .PARAMETER Close
        If specified, the dialog shows a single "Close" button instead of OK/Cancel. Clicking it (or
        closing the window) simply closes the form; no distinguished name is returned. Intended for
        browsing-only use (e.g. together with -DomainSelectionOnly or just to inspect the tree).

    .PARAMETER Tier0Regex
        A regular expression pattern used to identify Tier 0 objects. Default pattern matches:
        - CN=Administrator
        - OU=Domain Controllers
        - OU=Tier 0 (case-insensitive)
        - OU=T0 (case-insensitive)

    .OUTPUTS
        System.String
        Returns the distinguished name (DN) of the selected Active Directory object, or $null if the 
        user cancels the dialog.

    .EXAMPLE
        PS> Select-ADObject -Title "Select Target OU"
        Description: Displays the AD selection dialog with a custom title. Domains, OUs and containers
        are shown; objects below the domain level can be selected.

    .EXAMPLE
        PS> Select-ADObject -LocalDomainOnly -IncludeUsers -IncludeGroups
        Description: Shows only the current domain's contents, including users and groups in addition
        to OUs. Disabled users are marked with a red cross.

    .EXAMPLE
        PS> Select-ADObject -IncludeUsers -BlockOUSelection
        Description: Shows OUs for browsing, but only user objects can be selected. OUs and containers
        cannot be confirmed with OK.

    .EXAMPLE
        PS> Select-ADObject -IncludeUsers
        Description: Right-click a user and choose "Reset Password..." to set a new password (entered twice).
        The user can optionally be forced to change the password at next logon. Requires the Reset Password
        permission on the account; the password must satisfy the domain password policy.

    .EXAMPLE
        PS> Select-ADObject -DomainSelectionOnly
        Description: Restricts the selection to domain objects only.

    .EXAMPLE
        PS> Select-ADObject -MarkTier0 -IncludeUsers -Title "Select Tier 0 Target"
        Description: Displays all users and OUs, highlighting Tier 0 objects with a red dot.

    .EXAMPLE
        Select-ADObject -DomainController 'dc01.contoso.com' -LocalDomainOnly -IncludeUsers
        Uses the supplied controller to browse its domain.

    .EXAMPLE
        PS> Select-ADObject -Close -IncludeUsers -IncludeGroups -IncludeComputers
        Description: Shows the forest tree for browsing only. A single "Close" button replaces OK/Cancel;
        no distinguished name is returned.

    .NOTES
        - Author:      zimmermann.holger@live.de
        - Version:     2026.11.19.900
        - Last Update: 2026-11-19

        - This is a private function and requires a graphical environment (Windows Forms).
        - The function does not need the ActiveDirectory PowerShell module. Everything (forest browsing,
          OU creation, enabling/disabling accounts, password reset) uses System.DirectoryServices (LDAP/ADSI).
        - All logging is handled through Write-Log.
    #>

    [CmdletBinding()]
    param(
        [string]$Title = "Select AD Object",
		[string]$Version = "2026.11.14.33 | Standalone",
        [switch]$LocalDomainOnly,
        [switch]$DomainSelectionOnly,
        [switch]$AddOU,
        [switch]$BlockOUSelection,
        [switch]$IncludeLinkedGPOs,
        [switch]$IncludeUsers,
        [switch]$IncludeGroups,
        [switch]$IncludeComputers,
        [switch]$IncludeGPOs,
        [switch]$MarkTier0,
        [switch]$Close,
        [Switch]$ShowAdvanced,
        [string]$Tier0Regex = '(?i)(^CN=Administrator,|^OU=Domain Controllers,|^OU=Tier\s*0|^OU=T0)',
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$')]
        [string]$DomainController
    )

    If ($Script:NotStandAlone) {
        $Info = Measure-FunctionRuntime -Begin
    }


    # =========================
    # Assemblies
    # =========================
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.DirectoryServices
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Discover the forest before building the UI; an explicit DC must not fall back silently.
    $controllerDomain = $null
    $controllerName = $null
    if ($DomainController) {
        try {
            $context = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(
                [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::DirectoryServer,
                $DomainController
            )
            $controller = [System.DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($context)
            try {
                $forest = $controller.Forest
                $controllerDomain = $controller.Domain.Name
                $controllerName = $controller.Name
            }
            finally { $controller.Dispose() }
        }
        catch {
            throw "Unable to discover the forest through domain controller '$DomainController': $($_.Exception.Message)"
        }
    }
    else {
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    }


    # =========================
    # Modern Icon Creation
    # =========================

    <#
    .SYNOPSIS
    Creates a rounded-rectangle graphics path.

    .FUNCTIONALITY
    Builds the rounded paths used to draw the object-selection icons.
    #>
    function New-RoundedRectPath($X, $Y, $W, $H, $R) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc($X, $Y, $R, $R, 180, 90)
        $path.AddArc($X + $W - $R, $Y, $R, $R, 270, 90)
        $path.AddArc($X + $W - $R, $Y + $H - $R, $R, $R, 0, 90)
        $path.AddArc($X, $Y + $H - $R, $R, $R, 90, 90)
        $path.CloseFigure()
        $path
    }

    <#
    .SYNOPSIS
    Creates an icon bitmap for a directory object type.

    .FUNCTIONALITY
    Draws a 16-by-16 bitmap for the requested forest or Active Directory object type.
    #>
    function New-IconBitmap($Kind) {
        $bmp = New-Object System.Drawing.Bitmap 16, 16
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear([System.Drawing.Color]::Transparent)

        $stroke = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 60, 60), 1)
        $fill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 226, 232))

        switch ($Kind) {
            'Forest' {
                # Top node (Forest root)
                $g.FillEllipse($fill, 6, 2, 4, 4)
                $g.DrawEllipse($stroke, 6, 2, 4, 4)

                # Left child (Domain)
                $g.FillEllipse($fill, 3, 8, 4, 4)
                $g.DrawEllipse($stroke, 3, 8, 4, 4)

                # Right child (Domain)
                $g.FillEllipse($fill, 9, 8, 4, 4)
                $g.DrawEllipse($stroke, 9, 8, 4, 4)

                # Connection lines
                $g.DrawLine($stroke, 8, 6, 5, 8)
                $g.DrawLine($stroke, 8, 6, 11, 8)
            }
            'Domain' {
                $points = [System.Drawing.Point[]]@(
                    (New-Object System.Drawing.Point 8, 3),
                    (New-Object System.Drawing.Point 13, 12),
                    (New-Object System.Drawing.Point 3, 12)
                )

                $g.FillPolygon($fill, $points)
                $g.DrawPolygon($stroke, $points)
                $g.DrawLine($stroke, 5, 9, 11, 9)
            }
            'OU' {
                $p = New-RoundedRectPath 2 5 12 8 3
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)
            }
            'Container' {
                $p = New-RoundedRectPath 3 4 10 10 3
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)
                $g.DrawLine($stroke, 4, 8, 12, 8)
            }
            'User' {
                $g.FillEllipse($fill, 5, 3, 6, 6)
                $g.DrawEllipse($stroke, 5, 3, 6, 6)

                $p = New-RoundedRectPath 3 9 10 5 3
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)
            }
            'Computer' {
                $p = New-RoundedRectPath 2 3 12 8 2
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)

                $g.DrawLine($stroke, 6, 12, 10, 12)
                $g.DrawLine($stroke, 8, 11, 8, 14)
            }
            'Group' {
                $g.FillEllipse($fill, 4, 4, 4, 4)
                $g.DrawEllipse($stroke, 4, 4, 4, 4)

                $g.FillEllipse($fill, 8, 4, 4, 4)
                $g.DrawEllipse($stroke, 8, 4, 4, 4)

                $p = New-RoundedRectPath 4 9 8 4 3
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)
            }
            'GPO' {
                # Center gear
                $g.FillEllipse($fill, 6, 6, 4, 4)
                $g.DrawEllipse($stroke, 6, 6, 4, 4)
                $g.FillEllipse([System.Drawing.Brushes]::White, 7, 7, 2, 2)
                $g.DrawEllipse($stroke, 7, 7, 2, 2)

                # Top tooth
                $p = New-RoundedRectPath 7 1 2 3 1
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)

                # Right tooth
                $p = New-RoundedRectPath 12 7 3 2 1
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)

                # Bottom tooth
                $p = New-RoundedRectPath 7 12 2 3 1
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)

                # Left tooth
                $p = New-RoundedRectPath 1 7 3 2 1
                $g.FillPath($fill, $p)
                $g.DrawPath($stroke, $p)
            }
        }
        $g.Dispose()
        $bmp
    }

    <#
    .SYNOPSIS
    Marks an icon as belonging to Tier 0.

    .FUNCTIONALITY
    Adds a red overlay to the supplied bitmap.
    #>
    function Add-TierOverlay($bmp) {
        $clone = $bmp.Clone()
        $g = [System.Drawing.Graphics]::FromImage($clone)
        $g.FillEllipse([System.Drawing.Brushes]::Red, 10, 1, 5, 5)
        $g.Dispose()
        $clone
    }

    <#
    .SYNOPSIS
    Marks an icon as belonging to a disabled account.

    .FUNCTIONALITY
    Adds a small red cross in the bottom-right corner to the supplied bitmap.
    #>
    function Add-DisabledOverlay($bmp) {
        $clone = $bmp.Clone()
        $g = [System.Drawing.Graphics]::FromImage($clone)
        $g.SmoothingMode = 'AntiAlias'
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2)
        $g.DrawLine($pen, 10, 10, 14, 14)
        $g.DrawLine($pen, 14, 10, 10, 14)
        $pen.Dispose()
        $g.Dispose()
        $clone
    }

    # =========================
    # ImageList
    # =========================

    $imageList = New-Object System.Windows.Forms.ImageList
    $imageList.ImageSize = '16,16'

    $imageList.Images.Add("Forest", (New-IconBitmap Forest)) | Out-Null
    $imageList.Images.Add("Domain", (New-IconBitmap Domain)) | Out-Null
    $imageList.Images.Add("OU", (New-IconBitmap OU)) | Out-Null
    $imageList.Images.Add("Container", (New-IconBitmap Container)) | Out-Null
    $imageList.Images.Add("User", (New-IconBitmap User)) | Out-Null
    $imageList.Images.Add("Computer", (New-IconBitmap Computer)) | Out-Null
    $imageList.Images.Add("Group", (New-IconBitmap Group)) | Out-Null
    $imageList.Images.Add("GPO", (New-IconBitmap GPO)) | Out-Null

    if ($MarkTier0) {
        foreach ($k in @("User", "OU", "Container", "Computer", "Group", "GPO")) {
            $imageList.Images.Add("${k}_T0", (Add-TierOverlay $imageList.Images[$k])) | Out-Null
        }
    }

    # Disabled variants (user and computer accounts), also combined with the Tier 0 marker
    foreach ($k in @("User", "Computer")) {
        $imageList.Images.Add("${k}_Disabled", (Add-DisabledOverlay $imageList.Images[$k])) | Out-Null
        if ($MarkTier0) {
            $imageList.Images.Add("${k}_T0_Disabled", (Add-DisabledOverlay $imageList.Images["${k}_T0"])) | Out-Null
        }
    }

    # =========================
    # Helpers
    # =========================

    <#
    .SYNOPSIS
    Converts a DNS domain name to a distinguished name.

    .FUNCTIONALITY
    Converts each domain component into a DC element.
    #>
    function Convert-DomainToDN($d) { 'DC=' + ($d -replace '\.', ',DC=') }

    <#
    .SYNOPSIS
    Escapes a value for use in a relative distinguished name (RFC 4514).

    .FUNCTIONALITY
    Escapes special LDAP characters so a name like "Sales, EMEA" can be used in an RDN.
    #>
    function ConvertTo-EscapedRdnValue([string]$Value) {
        $escaped = $Value -replace '([,\\+"<>;=])', '\$1'
        $escaped = $escaped -replace '^([ #])', '\$1'
        $escaped = $escaped -replace '( )$', '\$1'
        $escaped
    }

    <#
    .SYNOPSIS
    Creates an organizational unit without the ActiveDirectory module.

    .FUNCTIONALITY
    Uses System.DirectoryServices to create the OU below the given parent DN on the given domain
    and protects it from accidental deletion. Returns the distinguished name of the new OU.
    #>
    function New-OUViaLdap([string]$Name, [string]$ParentDN, [string]$Server) {
        $parent = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$ParentDN")
        $ou = $parent.Children.Add("OU=$(ConvertTo-EscapedRdnValue $Name)", 'organizationalUnit')
        $ou.CommitChanges()
        $ou.RefreshCache(@('distinguishedName'))
        $newDn = [string]$ou.Properties['distinguishedName'][0]

        # Same default as New-ADOrganizationalUnit: protect from accidental deletion (non-fatal if it fails)
        try {
            $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
            $rights = [System.DirectoryServices.ActiveDirectoryRights]'Delete,DeleteTree'
            $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $everyone, $rights, [System.Security.AccessControl.AccessControlType]::Deny)
            $ou.ObjectSecurity.AddAccessRule($rule)
            $ou.CommitChanges()
        }
        catch { Write-Verbose "Could not set accidental deletion protection on '$newDn': $_" }

        $newDn
    }

    <#
    .SYNOPSIS
    Enables or disables an account without the ActiveDirectory module.

    .FUNCTIONALITY
    Sets or clears the ACCOUNTDISABLE flag (0x2) in userAccountControl via System.DirectoryServices.
    #>
    function Set-AccountEnabledViaLdap([string]$DistinguishedName, [string]$Server, [bool]$Enabled) {
        $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$DistinguishedName")
        $uac = [int]$entry.Properties['userAccountControl'][0]
        if ($Enabled) { $uac = $uac -band (-bnot 2) } else { $uac = $uac -bor 2 }
        $entry.Properties['userAccountControl'].Value = $uac
        $entry.CommitChanges()
    }

    <#
    .SYNOPSIS
    Resets a user's password without the ActiveDirectory module.

    .FUNCTIONALITY
    Calls the ADSI SetPassword method (IADsUser) and optionally sets pwdLastSet to 0 so the user must
    change the password at next logon.
    #>
    function Set-PasswordViaLdap([string]$DistinguishedName, [string]$Server, [string]$NewPassword, [bool]$MustChange) {
        $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$DistinguishedName")
        try {
            $entry.Invoke('SetPassword', @($NewPassword)) | Out-Null
            if ($MustChange) {
                $entry.Properties['pwdLastSet'].Value = 0
                $entry.CommitChanges()
            }
        }
        catch [System.Reflection.TargetInvocationException] {
            # Unwrap the COM exception so the real reason (e.g. policy violation) is shown
            throw $_.Exception.InnerException
        }
        finally { $entry.Dispose() }
    }

    <#
    .SYNOPSIS
    Prompts for a new password.

    .FUNCTIONALITY
    Shows a dialog with two masked password fields and a "must change at next logon" option.
    Returns an object with Password and MustChange, or nothing when cancelled.
    #>
    function Show-PasswordPrompt([string]$UserName) {
        $dialog = New-Object System.Windows.Forms.Form
        $dialog.Text = "Reset Password"
        $dialog.Size = '360,230'
        $dialog.StartPosition = 'CenterParent'
        $dialog.FormBorderStyle = 'FixedDialog'
        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "New password for ${UserName}:"
        $label.Location = '12,12'
        $label.Size = '320,20'

        $pw1 = New-Object System.Windows.Forms.TextBox
        $pw1.Location = '12,34'
        $pw1.Size = '320,22'
        $pw1.UseSystemPasswordChar = $true

        $label2 = New-Object System.Windows.Forms.Label
        $label2.Text = "Confirm password:"
        $label2.Location = '12,64'
        $label2.Size = '320,20'

        $pw2 = New-Object System.Windows.Forms.TextBox
        $pw2.Location = '12,86'
        $pw2.Size = '320,22'
        $pw2.UseSystemPasswordChar = $true

        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = "User must change password at next logon"
        $chk.Location = '12,116'
        $chk.Size = '320,20'

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "Reset"
        $okButton.Location = '172,150'
        $okButton.Size = '75,26'
        $okButton.Add_Click({
                if ([string]::IsNullOrEmpty($pw1.Text)) {
                    [void][System.Windows.Forms.MessageBox]::Show($dialog, "The password must not be empty.", "Reset Password",
                        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
                elseif ($pw1.Text -cne $pw2.Text) {
                    [void][System.Windows.Forms.MessageBox]::Show($dialog, "The passwords do not match.", "Reset Password",
                        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
                else {
                    $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
                }
            })

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Cancel"
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $cancelButton.Location = '257,150'
        $cancelButton.Size = '75,26'

        $dialog.AcceptButton = $okButton
        $dialog.CancelButton = $cancelButton
        $dialog.Controls.AddRange(@($label, $pw1, $label2, $pw2, $chk, $okButton, $cancelButton))

        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            [PSCustomObject]@{ Password = $pw1.Text; MustChange = $chk.Checked }
        }
        $pw1.Text = ''
        $pw2.Text = ''
        $dialog.Dispose()
    }

    <#
    .SYNOPSIS
    Returns the domain names in the current forest.

    .FUNCTIONALITY
    Reads and returns every domain name from the current Active Directory forest.
    #>
    function Get-ForestDomains {
        $forest.Domains |
        Select-Object -ExpandProperty Name
    }

    <#
    .SYNOPSIS
    Loads child objects for a node in the selection tree.

    .FUNCTIONALITY
    Queries LDAP for matching OUs, containers, and enabled object types on demand.
    #>
    function Get-ChildNodes($node) {

        if ($DomainSelectionOnly) { return }

        if ($node.Nodes.Count -eq 1 -and $node.Nodes[0].Text -eq 'dummy') {

            $node.Nodes.Clear()

            $ldapPath = if ($DomainController) { "LDAP://$($node.Tag.Server)/$($node.Name)" } else { "LDAP://$($node.Name)" }
            $root = [ADSI]$ldapPath
            $searcher = New-Object System.DirectoryServices.DirectorySearcher($root)
            $searcher.SearchScope = 'OneLevel'
            
            $filters = @(
                "(objectClass=organizationalUnit)",
                "(objectClass=container)",
                "(objectClass=builtinDomain)"
            )

            if ($IncludeUsers) { $filters += "(objectCategory=user)" }
            if ($IncludeGroups) { $filters += "(objectCategory=group)" }
            if ($IncludeComputers) { $filters += "(objectCategory=computer)" }
            if ($IncludeGPOs) { $filters += "(objectCategory=groupPolicyContainer)" }

            $orFilter = "(|" + ($filters -join "") + ")"

            if (-not $ShowAdvanced) {
                $searcher.Filter = "(& $orFilter (!(showInAdvancedViewOnly=TRUE)))"
            }
            else {
                $searcher.Filter = $orFilter
            }
          
            write-verbose $orFilter
		  
            $null = $searcher.PropertiesToLoad.AddRange(@("name", "distinguishedName", "objectClass", "userAccountControl"))

            foreach ($res in $searcher.FindAll()) {

                $dn = $res.Properties.distinguishedname[0]
                $name = $res.Properties.name[0]
                $cls = $res.Properties.objectclass[-1]
                # change icon here
                #$iconKey = if ($cls -eq "organizationalUnit") { "OU" } else { "User" }

                $iconKey = switch ($cls) {
                    'organizationalUnit' { 'OU' }
                    'container' { 'Container' }
                    'user' { 'User' }
                    'group' { 'Group' }
                    'computer' { 'Computer' }
                    'groupPolicyContainer' { 'GPO' }
                    default { 'Container' }
                }

                if ($MarkTier0 -and $dn -match $Tier0Regex -and $imageList.Images.ContainsKey("${iconKey}_T0")) {
                    $iconKey = "${iconKey}_T0"
                }

                # Disabled accounts: UF_ACCOUNTDISABLE = 0x2 in userAccountControl
                $isDisabled = $false
                if ($cls -in @('user', 'computer') -and $res.Properties['useraccountcontrol'].Count -gt 0) {
                    $uac = [int]$res.Properties['useraccountcontrol'][0]
                    $isDisabled = [bool]($uac -band 2)
                    if ($isDisabled -and $imageList.Images.ContainsKey("${iconKey}_Disabled")) {
                        $iconKey = "${iconKey}_Disabled"
                    }
                }

                $child = New-Object System.Windows.Forms.TreeNode
                $child.Text = $name
                $child.Name = $dn
                $child.Tag = [PSCustomObject]@{ Domain = $node.Tag.Domain; Server = $node.Tag.Server; ObjectClass = $cls; IsDisabled = $isDisabled }
                $child.ImageKey = $iconKey
                $child.SelectedImageKey = $iconKey
                $child.Nodes.Add("dummy") | Out-Null

                $node.Nodes.Add($child) | Out-Null
            }

            if ($IncludeLinkedGPOs -and $root.Properties['gPLink'].Count -gt 0) {
                $gpoLinks = [regex]::Matches(
                    [string]$root.Properties['gPLink'][0],
                    '\[LDAP://(?<dn>[^;]+);\d+\]'
                )

                $gpoIndex = 0
                foreach ($gpoLink in $gpoLinks) {
                    $gpoDn = $gpoLink.Groups['dn'].Value
                    $gpoPath = if ($DomainController) { "LDAP://$($node.Tag.Server)/$gpoDn" } else { "LDAP://$gpoDn" }
                    $gpoRoot = [ADSI]$gpoPath
                    $gpoSearcher = New-Object System.DirectoryServices.DirectorySearcher($gpoRoot)
                    $gpoSearcher.SearchScope = 'Base'
                    $gpoSearcher.Filter = '(objectClass=groupPolicyContainer)'
                    $null = $gpoSearcher.PropertiesToLoad.Add('displayName')
                    $gpoResult = $gpoSearcher.FindOne()

                    if (-not $gpoResult) { continue }

                    $gpoDisplayName = [string]$gpoResult.Properties['displayname'][0]
                    if ([string]::IsNullOrWhiteSpace($gpoDisplayName)) {
                        $gpoDisplayName = $gpoDn
                    }

                    $gpoNode = New-Object System.Windows.Forms.TreeNode
                    $gpoNode.Text = $gpoDisplayName
                    $gpoNode.Name = $gpoDn
                    $gpoNode.Tag = [PSCustomObject]@{ Domain = $node.Tag.Domain; Server = $node.Tag.Server; ObjectClass = 'groupPolicyContainer' }
                    $gpoNode.ImageKey = 'GPO'
                    $gpoNode.SelectedImageKey = 'GPO'
                    $node.Nodes.Insert($gpoIndex, $gpoNode)
                    $gpoIndex++
                }
            }
        }
    }

    <#
    .SYNOPSIS
    Prompts for a new organizational unit name.

    .FUNCTIONALITY
    Shows a small dialog and returns the entered OU name when confirmed.
    #>
    function Show-OUNamePrompt {
        $dialog = New-Object System.Windows.Forms.Form
        $dialog.Text = "New Organizational Unit"
        $dialog.Size = '360,140'
        $dialog.StartPosition = 'CenterParent'
        $dialog.FormBorderStyle = 'FixedDialog'
        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Organizational unit name:"
        $label.Location = '12,12'
        $label.Size = '320,20'

        $nameTextBox = New-Object System.Windows.Forms.TextBox
        $nameTextBox.Location = '12,36'
        $nameTextBox.Size = '320,22'

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "Create"
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $okButton.Location = '172,68'
        $okButton.Size = '75,26'

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Cancel"
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $cancelButton.Location = '257,68'
        $cancelButton.Size = '75,26'

        $dialog.AcceptButton = $okButton
        $dialog.CancelButton = $cancelButton
        $dialog.Controls.AddRange(@($label, $nameTextBox, $okButton, $cancelButton))

        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            return $nameTextBox.Text.Trim()
        }
    }

    # =========================
    # FORM
    # =========================

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = '520,700'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Padding = '10,10,10,10'

    $font = New-Object System.Drawing.Font("Segoe UI", 9)

    $tree = New-Object System.Windows.Forms.TreeView
    $tree.Location = '10,10'
    $tree.Size = '480,560'
    $tree.Font = $font
    $tree.ImageList = $imageList

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = '10,580'
    $statusLabel.Size = '480,20'
    $statusLabel.Text = "Selected: none"
    $statusLabel.Font = $font

    if ($Close) {
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Text = "Close"
        $btnClose.Location = '410,610'
        $btnClose.Size = '80,28'
        $btnClose.Font = $font

        $form.AcceptButton = $btnClose
        $form.CancelButton = $btnClose
    }
    else {
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"
        $btnCancel.Location = '310,610'
        $btnCancel.Size = '80,28'
        $btnCancel.Font = $font

        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Text = "OK"
        $btnOK.Location = '410,610'
        $btnOK.Size = '80,28'
        $btnOK.Font = $font
        $btnOK.Enabled = $false

        $form.AcceptButton = $btnOK
        $form.CancelButton = $btnCancel
    }

    # =========================
    # Build Forest
    # =========================

    $forestName = $forest.Name

    $forestNode = New-Object System.Windows.Forms.TreeNode
    $forestNode.Text = $forestName
    $forestNode.ImageKey = "Forest"
    $forestNode.SelectedImageKey = "Forest"
    $tree.Nodes.Add($forestNode) | Out-Null

    $domains = Get-ForestDomains
    $currentDomain = if ($DomainController) { $controllerDomain } else { ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name }

    foreach ($d in $domains) {

        if ($LocalDomainOnly -and $d -ne $currentDomain) { continue }

        $dn = Convert-DomainToDN $d

        $domainNode = New-Object System.Windows.Forms.TreeNode
        $domainNode.Text = $d
        $domainNode.Name = $dn
        $server = if ($DomainController -and $d -eq $controllerDomain) { $controllerName } else { $d }
        $domainNode.Tag = [PSCustomObject]@{ Domain = $d; Server = $server; ObjectClass = 'domain' }
        $domainNode.ImageKey = "Domain"
        $domainNode.SelectedImageKey = "Domain"
        $domainNode.Nodes.Add("dummy") | Out-Null

        $forestNode.Nodes.Add($domainNode) | Out-Null
    }

    $forestNode.Expand()

    # =========================
    # Events
    # =========================

    $tree.add_BeforeExpand({ Get-ChildNodes $_.Node })

    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $newMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("New")
    $addOuMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Organizational Unit")
    $accountMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Disable Account")
    if ($AddOU) {
        $newMenuItem.DropDownItems.Add($addOuMenuItem) | Out-Null
        $contextMenu.Items.Add($newMenuItem) | Out-Null
    }
    $contextMenu.Items.Add($accountMenuItem) | Out-Null
    $resetPwMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Reset Password...")
    $contextMenu.Items.Add($resetPwMenuItem) | Out-Null
    $tree.ContextMenuStrip = $contextMenu

    $tree.add_MouseDown({
            if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
                $node = $tree.GetNodeAt($_.Location)
                $tree.SelectedNode = $node
            }
        })

    $contextMenu.add_Opening({
            $node = $tree.SelectedNode
            $objectClass = $node.Tag.ObjectClass
            $newMenuItem.Visible = $AddOU -and $objectClass -in @('domain', 'organizationalUnit', 'container', 'builtinDomain')
            $accountMenuItem.Visible = $objectClass -eq 'user'
            $accountMenuItem.Text = if ($node.Tag.IsDisabled) { 'Enable Account' } else { 'Disable Account' }
            $resetPwMenuItem.Visible = $objectClass -eq 'user'
            $_.Cancel = -not ($newMenuItem.Available -or $accountMenuItem.Available -or $resetPwMenuItem.Available)
        })

    $resetPwMenuItem.add_Click({
            $node = $tree.SelectedNode
            if (-not $node -or $node.Tag.ObjectClass -ne 'user') { return }

            $request = Show-PasswordPrompt -UserName $node.Text
            if (-not $request) { return }

            try {
                Set-PasswordViaLdap -DistinguishedName $node.Name -Server $node.Tag.Server `
                    -NewPassword $request.Password -MustChange ([bool]$request.MustChange)
                if ($Script:NotStandAlone) {
                    Write-Log -Message "Password reset for '$($node.Name)'"
                }
                [void][System.Windows.Forms.MessageBox]::Show(
                    $form, "Password for '$($node.Text)' was reset.", "Reset Password",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            catch {
                if ($Script:NotStandAlone) {
                    Write-Log -Message "Failed to reset password for '$($node.Name)': $($_.Exception.Message)"
                }
                [void][System.Windows.Forms.MessageBox]::Show(
                    $form, $_.Exception.Message, "Reset Password failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
            finally { $request = $null }
        })

    $accountMenuItem.add_Click({
            $node = $tree.SelectedNode
            if ($node.Tag.ObjectClass -ne 'user') { return }

            $enable = $node.Tag.IsDisabled
            $action = if ($enable) { 'Enable' } else { 'Disable' }

            try {
                Set-AccountEnabledViaLdap -DistinguishedName $node.Name -Server $node.Tag.Server -Enabled ([bool]$enable)
            }
            catch {
                [void][System.Windows.Forms.MessageBox]::Show(
                    $form, $_.Exception.Message, "$action Account failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }

            $node.Tag.IsDisabled = -not $enable
            $iconKey = $node.ImageKey -replace '_Disabled$', ''
            if ($node.Tag.IsDisabled) { $iconKey = "${iconKey}_Disabled" }
            $node.ImageKey = $iconKey
            $node.SelectedImageKey = $iconKey
        })

    if ($AddOU) {
        $addOuMenuItem.add_Click({
                $parentNode = $tree.SelectedNode
                if (-not $parentNode -or -not $parentNode.Tag -or $parentNode.Tag.ObjectClass -notin @('domain', 'organizationalUnit', 'container', 'builtinDomain')) {
                    return
                }

                $ouName = Show-OUNamePrompt
                if ([string]::IsNullOrWhiteSpace($ouName)) {
                    return
                }

                try {
                    $createdOuDn = New-OUViaLdap -Name $ouName -ParentDN $parentNode.Name -Server $parentNode.Tag.Server
                    if ($Script:NotStandAlone) {
                        Write-Log -Message "Created organizational unit '$createdOuDn'"
                    }

                    # Refresh the parent's child nodes so the new OU is shown immediately
                    $tree.BeginUpdate()
                    try {
                        $parentNode.Nodes.Clear()
                        $parentNode.Nodes.Add("dummy") | Out-Null
                        Get-ChildNodes $parentNode
                        $parentNode.Expand()

                        $newNode = $parentNode.Nodes | Where-Object { $_.Name -eq $createdOuDn } | Select-Object -First 1
                        if ($newNode) {
                            $newNode.EnsureVisible()
                            $tree.SelectedNode = $newNode
                        }
                    }
                    finally {
                        $tree.EndUpdate()
                    }
                }
                catch {
                    if ($Script:NotStandAlone) {
                        Write-Log -Message "Failed to create organizational unit '$ouName' under '$($parentNode.Name)': $_"
                    }
                    [void][System.Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, "OU creation failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            })
    }

    $tree.add_AfterSelect({
            $node = $_.Node
            $statusLabel.Text = "Selected: $($node.Text)"

            if ($Close) { return }

            if ($DomainSelectionOnly) {
                $btnOK.Enabled = ($node.Parent -and -not $node.Parent.Parent)
                return
            }

            # Selectable only below the domain level (forest and domain nodes are never selectable here)
            $selectable = [bool]($node.Parent -and $node.Parent.Parent)

            # -BlockOUSelection: OUs and containers stay browsable but cannot be selected
            if ($selectable -and $BlockOUSelection -and $node.Tag -and
                $node.Tag.ObjectClass -in @('organizationalUnit', 'container', 'builtinDomain')) {
                $selectable = $false
            }

            $btnOK.Enabled = $selectable
        })

    if ($Close) {
        $btnClose.add_Click({
                $form.Tag = $null
                $form.Close()
            })

        $form.Controls.AddRange(@($tree, $statusLabel, $btnClose))
    }
    else {
        $btnOK.add_Click({
                $form.Tag = $tree.SelectedNode.Name
                $form.Close()
            })

        $btnCancel.add_Click({
                $form.Tag = $null
                $form.Close()
            })

        $form.Controls.AddRange(@($tree, $statusLabel, $btnCancel, $btnOK))
    }

    # Standalone start: show the version in the bottom-left corner (keep in sync with .NOTES)
    if (-not $Script:NotStandAlone) {
        $versionLabel = New-Object System.Windows.Forms.Label
        $versionLabel.Text = "Version $Version"
        $versionLabel.Location = '10,617'
        $versionLabel.Size = '200,18'
        $versionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        $versionLabel.ForeColor = [System.Drawing.Color]::Gray
        $form.Controls.Add($versionLabel)
    }

    $null = $form.ShowDialog()
    If ($Script:NotStandAlone) {
        Write-Log -Message "    >> AD Object selected: $($form.Tag)"
        Measure-FunctionRuntime -End -Details $Info
    }
    else {
        Write-Host "    >> AD Object selected: $($form.Tag)"
    }
    return $form.Tag
    
}
