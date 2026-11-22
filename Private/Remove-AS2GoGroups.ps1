<#
.SYNOPSIS
Reverts the AS2Go group nesting and removes the AS2Go security groups.

.DESCRIPTION
Undoes what Initialize-AS2GoAssets did to existing Active Directory objects, in reverse order:
removes the AS2Go help desk/victim groups from the local Administrators group on the configured
target machine, removes the AS2Go admin groups from Domain Admins/Server Operators/Enterprise
Admins, moves the built-in Domain Admins (-512) and Enterprise Admins (-519) groups back from the
Tier 0 Groups OU to their default CN=Users container, lifts the deny ACE/disabled inheritance on
the Tier 0 Assets OU, and finally deletes the five AS2Go security groups themselves.

.PARAMETER Scenario
Scenario label used to resolve the AS2Go OU path. Defaults to AS2Go.

.PARAMETER Server
Domain controller used for Active Directory operations in the current domain.

.PARAMETER LocalAdminHost
Hostname whose local Administrators group received the AS2Go help desk/victim groups. Falls back
to the AS2GoSAW/AS2GoAppServer configuration settings, then prompts if neither is available.

.PARAMETER RevertNestingOnly
Only reverts local/AD group nesting, moves privileged groups back, and restores the Tier 0 ACL.
Used by Remove-AS2GoLab -All to run this before removing demo accounts, which may still be members.

.PARAMETER DeleteGroupsOnly
Only deletes the AS2Go security groups. Used by Remove-AS2GoLab -All to run this after demo
accounts have been removed. Without either switch, both phases run.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Reverts local and AD group nesting, moves built-in privileged groups back to CN=Users, lifts the
Tier 0 deny ACE/inheritance, then deletes the AS2Go security groups.
#>
function Remove-AS2GoGroups {

    param(
        [string] $Scenario = "AS2Go",
        [Parameter(Mandatory)]
        [string] $Server,
        [string] $LocalAdminHost,
        [switch] $RevertNestingOnly,
        [switch] $DeleteGroupsOnly
    )

    $Info = Measure-FunctionRuntime -Begin
    $RunRevert = $DeleteGroupsOnly -eq $false
    $RunDelete = $RevertNestingOnly -eq $false

    $HDGroup = Get-ASConfig -Setting "HDGroup"
    $CAGroup = Get-ASConfig -Setting "CAGroup"
    $DAGroup = Get-ASConfig -Setting "DAGroup"
    $SAGroup = Get-ASConfig -Setting "SAGroup"
    $EAGroup = Get-ASConfig -Setting "EAGroup"
    $BDUsersOU = Get-ASConfig -Setting "BDUsersOU"
    $RootDC = Get-BestDomainController -Domain ((Get-ADForest).RootDomain)

    if ($RunRevert) {

    ################################################################################
    #####   1) Revert local Administrators membership on the target machine  #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Reverting local Administrators membership"

    if ([string]::IsNullOrWhiteSpace($LocalAdminHost)) {
        $LocalAdminHost = Get-ASConfig -Setting "AS2GoSAW"
        if ([string]::IsNullOrWhiteSpace($LocalAdminHost)) {
            $LocalAdminHost = Get-ASConfig -Setting "AS2GoAppServer"
        }
    }

    if ([string]::IsNullOrWhiteSpace($LocalAdminHost)) {
        Write-AS2GoOutput -Type Warning -Message "No target machine is configured (AS2GoSAW/AS2GoAppServer)."
        $LocalAdminHost = Read-Host "`n  [>] Enter the hostname whose local Administrators group should be cleaned up, or press Enter to skip"
    }

    if (-not [string]::IsNullOrWhiteSpace($LocalAdminHost)) {
        $DomainNetBIOS = (Get-ADDomain -Server $Server).NetBIOSName
        $ScriptBlock = {
            param($DomainNetBIOS, $Groups)
            foreach ($group in $Groups) {
                try {
                    Remove-LocalGroupMember -Group "Administrators" -Member "$DomainNetBIOS\$group" -ErrorAction Stop
                    "Removed '$group' from local Administrators"
                }
                catch [Microsoft.PowerShell.Commands.MemberNotFoundException] {
                    "'$group' was not a member of local Administrators"
                }
                catch {
                    "Failed to remove '$group': $_"
                }
            }
        }
        try {
            if ($LocalAdminHost -eq $env:COMPUTERNAME) {
                & $ScriptBlock $DomainNetBIOS @($HDGroup, $CAGroup) | ForEach-Object { Write-AS2GoOutput -Type Info -Message $_ }
            }
            else {
                Invoke-Command -ComputerName $LocalAdminHost -ScriptBlock $ScriptBlock -ArgumentList $DomainNetBIOS, @($HDGroup, $CAGroup) -ErrorAction Stop | ForEach-Object { Write-AS2GoOutput -Type Info -Message $_ }
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Failed to clean up local Administrators on '$LocalAdminHost': $_"
        }
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "Skipped local Administrators cleanup - no target machine was supplied."
    }

    ################################################################################
    #####   2) Revert AD group nesting                                        #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Reverting AS2Go group nesting"

    $DomainAdminsSID = (Get-ADDomain -Server $Server).DomainSid.Value + "-512"
    $ServerOperatorsSID = "S-1-5-32-549"
    $EnterpriseAdminsSID = (Get-ADDomain -Server $RootDC).DomainSid.Value + "-519"

    $Nestings = @(
        [pscustomobject]@{ Name = $DAGroup; Parent = "Domain Admins"; ParentSID = $DomainAdminsSID; Server = $Server }
        [pscustomobject]@{ Name = $SAGroup; Parent = "Server Operators"; ParentSID = $ServerOperatorsSID; Server = $Server }
        [pscustomobject]@{ Name = $EAGroup; Parent = "Enterprise Admins"; ParentSID = $EnterpriseAdminsSID; Server = $RootDC }
    )

    foreach ($Nesting in $Nestings) {
        if ([string]::IsNullOrWhiteSpace($Nesting.Name)) { continue }
        try {
            if ($Nesting.Server -eq $Server) {
                Remove-ADGroupMember -Identity $Nesting.ParentSID -Members $Nesting.Name -Server $Nesting.Server -Confirm:$false -ErrorAction Stop
            }
            else {
                $MemberDN = (Get-ADGroup -Identity $Nesting.Name -Server $Server).DistinguishedName
                $ParentGroup = Get-ADGroup -Identity $Nesting.ParentSID -Server $Nesting.Server -Properties member
                Set-ADGroup -Identity $ParentGroup.DistinguishedName -Remove @{ member = $MemberDN } -Server $Nesting.Server -ErrorAction Stop
            }
            Write-AS2GoOutput -Type Success -Message "Removed '$($Nesting.Name)' from the '$($Nesting.Parent)' group" -NoExtraLines
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Failed to remove '$($Nesting.Name)' from the '$($Nesting.Parent)' group (it may already be gone): $_"
        }
    }

    ################################################################################
    #####   3) Move built-in privileged groups back to CN=Users               #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Moving privileged groups back to their default container"

    if (-not [string]::IsNullOrWhiteSpace($BDUsersOU)) {
        $Tier0GroupsOU = "OU=T0 Groups,OU=Tier 0 Assets,$BDUsersOU"

        $MoveBacks = @(
            [pscustomobject]@{ Sid = $DomainAdminsSID; Server = $Server; TargetDN = "CN=Users,$((Get-ADDomain -Server $Server).DistinguishedName)" }
            [pscustomobject]@{ Sid = $EnterpriseAdminsSID; Server = $RootDC; TargetDN = "CN=Users,$((Get-ADDomain -Server $RootDC).DistinguishedName)" }
        )

        foreach ($MoveBack in $MoveBacks) {
            try {
                $group = Get-ADGroup -Identity $MoveBack.Sid -Server $MoveBack.Server -ErrorAction Stop
                if ($group.DistinguishedName -like "*$Tier0GroupsOU") {
                    Move-ADObject -Identity $group.DistinguishedName -TargetPath $MoveBack.TargetDN -Server $MoveBack.Server -Confirm:$false -ErrorAction Stop
                    Write-AS2GoOutput -Type Success -Message "Moved '$($group.Name)' back to '$($MoveBack.TargetDN)'." -NoExtraLines
                }
                else {
                    Write-AS2GoOutput -Type Info -Message "'$($group.Name)' is not located under the Tier 0 Groups OU; leaving it in place."
                }
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Failed to move group with SID '$($MoveBack.Sid)' back: $_"
            }
        }

        ################################################################################
        #####   4) Lift the Tier 0 deny ACE and restore inheritance                #####
        ################################################################################

        Write-AS2GoOutput -Type Header -Message "Restoring Tier 0 ACL inheritance"

        $Tier0DN = "OU=Tier 0 Assets,$BDUsersOU"
        try {
            $TargetObject = Get-ADObject -Identity $Tier0DN -Server $Server -Properties nTSecurityDescriptor -ErrorAction Stop
            $acl = $TargetObject.nTSecurityDescriptor

            if (-not [string]::IsNullOrWhiteSpace($CAGroup)) {
                try {
                    $trustee = Get-ADGroup -Filter "SamAccountName -eq '$CAGroup'" -Server $Server -Properties SID -ErrorAction Stop
                    if ($trustee) {
                        $identity = [System.Security.Principal.IdentityReference]([System.Security.Principal.SecurityIdentifier]$trustee.SID)
                        $DenyAces = $acl.Access | Where-Object { $_.IdentityReference -eq $identity -and $_.AccessControlType -eq 'Deny' }
                        foreach ($ace in $DenyAces) { $acl.RemoveAccessRule($ace) | Out-Null }
                    }
                }
                catch {
                    Write-AS2GoOutput -Type Warning -Message "Could not resolve trustee '$CAGroup' to remove its deny ACE; it may already be deleted: $_"
                }
            }

            $acl.SetAccessRuleProtection($false, $true)
            Set-ADObject -Identity $Tier0DN -Server $Server -Replace @{ nTSecurityDescriptor = $acl } -ErrorAction Stop
            Write-AS2GoOutput -Type Success -Message "Restored inheritance on '$Tier0DN' and removed the deny ACE." -NoExtraLines
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Failed to restore the Tier 0 ACL on '$Tier0DN' (it may already be removed): $_"
        }
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "Setting 'BDUsersOU' is not configured; skipped moving privileged groups back and restoring Tier 0 ACLs."
    }

    } # end if ($RunRevert)

    if ($RunDelete) {

    ################################################################################
    #####   5) Delete the AS2Go security groups                               #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Removing AS2Go security groups"

    $GroupNames = @($DAGroup, $SAGroup, $HDGroup, $CAGroup, $EAGroup) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($GroupNames.Count -eq 0) {
        Write-AS2GoOutput -Type Warning -Message "No AS2Go group names are configured; nothing to delete."
    }
    else {
        $Options = @(
            [pscustomobject] @{ Label = "&Yes"; Help = "Delete the following groups: $($GroupNames -join ', ')"; Value = $Script:Yes },
            [pscustomobject] @{ Label = "&No"; Help = "Skip deleting the AS2Go security groups."; Value = $Script:No }
        )
        $answer = Show-DecisionPrompt -Message "Delete the AS2Go security groups?" -Options $Options -Default 1

        if ($answer -eq $Script:Yes) {
            foreach ($GroupName in $GroupNames) {
                $TargetServer = if ($GroupName -eq $EAGroup) { $RootDC } else { $Server }
                try {
                    Remove-ADGroup -Identity $GroupName -Server $TargetServer -Confirm:$false -ErrorAction Stop
                    Write-AS2GoOutput -Type Success -Message "Removed group '$GroupName'." -NoExtraLines
                }
                catch {
                    Write-AS2GoOutput -Type Warning -Message "Failed to remove group '$GroupName' (it may already be gone): $_"
                }
            }
        }
    }

    } # end if ($RunDelete)

    Measure-FunctionRuntime -End -Details $Info
}
