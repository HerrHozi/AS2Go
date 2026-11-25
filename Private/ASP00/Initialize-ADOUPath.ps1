<#
.SYNOPSIS
Ensures every OU in a distinguished-name path exists.

.PARAMETER Scenario
Scenario label written into the adminDescription tag of any OU this function creates. Defaults to AS2Go.

.FUNCTIONALITY
Creates missing parent and child OUs, tagging each new OU with the adminDescription creation tag,
then returns the requested Active Directory OU.
#>
function Initialize-ADOUPath {

    ################################################################################
    ######                                                                     #####
    ######    Check for AD OU Path, if missing create all OUs                  #####
    ######                                                                     #####
    ################################################################################

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DistinguishedName,
        [Parameter(Mandatory)]
        [string]$Server,
        [bool]$ProtectedFromAccidentalDeletion = $false,
        [string]$Scenario = "AS2Go"
    )

    $Info = Measure-FunctionRuntime -Begin

    $parts = $DistinguishedName -split '(?<!\\),'
    $ouParts = @($parts | Where-Object { $_ -like 'OU=*' })
    $dcParts = @($parts | Where-Object { $_ -like 'DC=*' })

    if ($ouParts.Count -eq 0) { throw "No OU components found in DN: $DistinguishedName" }
    if ($dcParts.Count -eq 0) { throw "No DC components found in DN: $DistinguishedName" }

    $domainDN = ($dcParts -join ',')

    # from Parent to Child
    $builtOUs = @()
    foreach ($ou in ($ouParts | Select-Object -Last $ouParts.Count)) {
        # ouParts liegen i.d.R. von Child->Parent im DN, daher umdrehen:
    }
    $ouParts = [System.Collections.Generic.List[string]]$ouParts
    $ouParts.Reverse()

    $pathDN = $domainDN

    foreach ($ou in $ouParts) {

        $currentDN = "$ou,$pathDN"   # DN des aktuellen OU-Levels
        $ouName = ($ou -replace '^OU=', '')  # Name ohne Prefix
        try {
            $exists = $null
            $exists = Get-ADOrganizationalUnit -Identity $currentDN -Server $Server -ErrorAction SilentlyContinue
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
        
        if (-not $exists) {
            New-ADOrganizationalUnit `
                -Name $ouName `
                -Path $pathDN `
                -PostalCode "AS2GoDemoAccounts" `
                -Description "Created by AS2Go PowerShell Module" `
                -OtherAttributes @{ 'adminDescription' = "AS2Go|$Scenario|ASP00|Create" } `
                -ProtectedFromAccidentalDeletion $ProtectedFromAccidentalDeletion `
                -Server $Server `
                -ErrorAction Stop

            Write-log -message  "    >> OU created: $currentDN"
        }
        else {
            Write-log -message  "    >> OU already exists: $currentDN"
        }
        $Script:ExistingOUs[$currentDN] = $true
        $pathDN = $currentDN
    }
    Measure-FunctionRuntime -End -Details $Info

    return Get-ADOrganizationalUnit -Identity $DistinguishedName -Server $Script:LogonServer -ErrorAction Stop
}