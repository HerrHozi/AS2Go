function Invoke-ADOUPathCheck {

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
        [bool]$ProtectedFromAccidentalDeletion = $false
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

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
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return Get-ADOrganizationalUnit -Identity $DistinguishedName -Server $Script:LogonServer -ErrorAction Stop
}