<#
.SYNOPSIS
Removes the AS2Go tiered OU structure.

.DESCRIPTION
Deletes the Tier 0/1/2 sub-OUs, the Tier OUs, the Demo Accounts OU, and the parent AS2Go OU, in
that order (children before parents), disabling accidental-deletion protection on each OU first.
Also deletes the configured Demo Accounts search base (AS2GoSearchBase) when it differs from the
default Demo Accounts OU - for example a custom OU selected or created through "Other OU" during
Invoke-DemoAccounts - but only when it carries the adminDescription creation tag for this scenario,
so an existing OU that was merely selected (not created by AS2Go) is never touched.
Intended to run after the AS2Go security groups, demo accounts, and named lab principals have
already been removed from these OUs.

.PARAMETER AS2GoOU
Name of the parent AS2Go organizational unit. Defaults to AS2Go.

.PARAMETER Scenario
Scenario label used to match the adminDescription tag on a custom Demo Accounts search base. Defaults to AS2Go.

.PARAMETER Server
Domain controller used for Active Directory operations.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Deletes the AS2Go Tier 0/1/2 sub-OUs, Tier OUs, Demo Accounts OU, parent OU, and (if tagged) a
custom Demo Accounts search base, bottom-up.
#>
function Remove-AS2GoOU {

    param(
        [string] $AS2GoOU = "AS2Go",
        [string] $Scenario = "AS2Go",
        [Parameter(Mandatory)]
        [string] $Server
    )

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Removing the AS2Go OU structure"

    $BDUsersOU = Get-ASConfig -Setting "BDUsersOU"
    if ([string]::IsNullOrWhiteSpace($BDUsersOU)) {
        $BDUsersOU = "OU=$AS2GoOU,$((Get-ADDomain -Server $Server).DistinguishedName)"
    }

    $cname = Convert-FromDNToCN -DistinguishedName $BDUsersOU

    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Delete the OU structure under '$cname', including any remaining objects."; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&No"; Help = "Skip deleting the AS2Go OU structure."; Value = $Script:No }
    )
    $answer = Show-DecisionPrompt -Message "Delete the AS2Go OU structure under '$cname'?" -Options $Options -Default 1

    if ($answer -ne $Script:Yes) {
        Write-AS2GoOutput -Type Info -Message "Skipped removing the AS2Go OU structure."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $SubTierOus = @("Accounts", "Groups", "Devices", "ServiceAccounts", "Servers")
    $TierNames = @("Tier 0 Assets", "Tier 1 Assets", "Tier 2 Assets")

    $OUsToDelete = [System.Collections.Generic.List[string]]::new()

    foreach ($TierName in $TierNames) {
        $TierDN = "OU=$TierName,$BDUsersOU"
        $TierIndex = $TierNames.IndexOf($TierName)
        foreach ($sub in $SubTierOus) {
            $OUsToDelete.Add("OU=T$TierIndex $sub,$TierDN")
        }
        $OUsToDelete.Add($TierDN)
    }
    $DefaultDemoAccountsOU = "OU=Demo Accounts,$BDUsersOU"
    $OUsToDelete.Add($DefaultDemoAccountsOU)

    # A custom Demo Accounts search base (selected or created through "Other OU" in Invoke-DemoAccounts)
    # is only queued for deletion when it carries the AS2Go creation tag, so an OU that was merely
    # selected - and not created by AS2Go - is never removed.
    $SearchBaseOU = Get-ASConfig -Setting "AS2GoSearchBase"
    if (-not [string]::IsNullOrWhiteSpace($SearchBaseOU) -and $SearchBaseOU -ne $DefaultDemoAccountsOU) {
        try {
            $SearchBaseObject = Get-ADObject -Identity $SearchBaseOU -Server $Server -Properties adminDescription -ErrorAction Stop
            if ($SearchBaseObject.adminDescription -eq "AS2Go|$Scenario|ASP00|Create") {
                $OUsToDelete.Add($SearchBaseOU)
            }
            else {
                Write-AS2GoOutput -Type Warning -Message "Configured Demo Accounts search base '$(Convert-FromDNToCN -DistinguishedName $SearchBaseOU)' does not carry the AS2Go creation tag; leaving it in place."
            }
        }
        catch {
            Write-AS2GoOutput -Type Info -Message "Configured Demo Accounts search base '$(Convert-FromDNToCN -DistinguishedName $SearchBaseOU)' was not found; skipping."
        }
    }

    $OUsToDelete.Add($BDUsersOU)

    foreach ($OUDN in $OUsToDelete) {
        try {
            $existing = Get-ADObject -Identity $OUDN -Server $Server -ErrorAction Stop
            if ($existing) {
                Set-ADOrganizationalUnit -Identity $OUDN -ProtectedFromAccidentalDeletion:$false -Server $Server -ErrorAction Stop
                Remove-ADOrganizationalUnit -Identity $OUDN -Recursive -Confirm:$false -Server $Server -ErrorAction Stop
                Write-AS2GoOutput -Type Success -Message "Removed OU '$(Convert-FromDNToCN -DistinguishedName $OUDN)'." -NoExtraLines
            }
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            Write-AS2GoOutput -Type Info -Message "OU '$(Convert-FromDNToCN -DistinguishedName $OUDN)' does not exist; skipping."
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Failed to remove OU '$OUDN': $_"
        }
    }

    Measure-FunctionRuntime -End -Details $Info
}
