<#
.SYNOPSIS
Migrates AS2Go lab objects created before the adminDescription tagging scheme to the new format.

.DESCRIPTION
The Update-AS2GoLabAttribute function finds AS2Go objects created by an older version of
Initialize-AS2GoLab, which only carried the legacy markers (adminDescription exactly "AS2GoAdmins",
"AS2GoHelpDesk", or "AS2GoVictims" on groups; PostalCode "AS2GoDemoAccounts"/"AS2GoTierung" on
OUs; and free-text Description values on users/computers), and writes the current
adminDescription tag (AS2Go|Scenario|ASP00|Create) onto them additively, without changing any
existing attribute value. This lets Remove-AS2GoLab discover and remove objects from lab
environments set up before this tagging scheme existed.

Objects that already carry the current tag format are left untouched.

.PARAMETER Scenario
Scenario label written into the new adminDescription tag. Defaults to AS2Go.

.PARAMETER Server
Domain controller used for Active Directory operations. Defaults to the current logon server.

.PARAMETER Preview
Shows a preview of this function instead of running it.

.PARAMETER WhatIf
Reports the objects that would be updated without changing anything.

.EXAMPLE
Update-AS2GoLabAttribute -WhatIf

Description: Reports every AS2Go object that would receive the new adminDescription tag, without
changing anything.

.EXAMPLE
Update-AS2GoLabAttribute -Scenario AS2Go

Description: Tags every AS2Go object found through the legacy markers with the current
adminDescription format for the "AS2Go" scenario.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
None. The function updates Active Directory objects and reports progress through console messages.

.NOTES
Author: AS2Go Team

Run this once per lab environment created before the adminDescription tagging scheme was
introduced, before using Remove-AS2GoLab on that environment.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Finds AS2Go objects tagged only with the legacy markers and additively writes the current
adminDescription tag (AS2Go|Scenario|ASP00|Create), without touching any existing attribute value.
#>
function Update-AS2GoLabAttribute {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Preview,
        [string] $Scenario = "AS2Go",
        [string] $Server
    )

    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Update-AS2GoLabAttribute' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

    $result = Test-LocalAdministrator
    if (-not $result.IsElevated) {
        Write-AS2GoOutput -Type Error -Message "This function must be run as Administrator."
        return
    }

    $info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $info.FunctionName

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Migrate AS2Go Lab Objects to the Current Tagging Scheme"
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality

    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = $Script:LogonServer
    }
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Get-LogonServerFQDN
    }

    $DomainDN = (Get-ADDomain -Server $Server).DistinguishedName
    $NewTag = "AS2Go|$Scenario|ASP00|Create"
    $Counters = [pscustomobject]@{ Updated = 0; Skipped = 0 }

    function Set-MigratedAdminDescription {
        param($Object, [string]$Value, [string]$ObjectTypeLabel, [pscustomobject]$Counters)

        if ($Object.adminDescription -like "*|*|ASP00|*") {
            Write-AS2GoOutput -Type Info -Message "$ObjectTypeLabel '$($Object.Name)' already carries the current tag; skipping." -NoExtraLines
            $Counters.Skipped++
            return
        }
        if ($PSCmdlet.ShouldProcess($Object.DistinguishedName, "Set adminDescription to '$Value'")) {
            try {
                Set-ADObject -Identity $Object.DistinguishedName -Replace @{ adminDescription = $Value } -Server $Server -ErrorAction Stop
                Write-AS2GoOutput -Type Success -Message "Tagged $ObjectTypeLabel '$($Object.Name)'." -NoExtraLines
                $Counters.Updated++
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Failed to tag $ObjectTypeLabel '$($Object.Name)': $_"
            }
        }
    }

    ################################################################################
    #####   1) OUs tagged only with the legacy PostalCode marker              #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Migrating AS2Go organizational units"
    $OUs = @(Get-ADOrganizationalUnit -LDAPFilter "(|(postalCode=AS2GoDemoAccounts)(postalCode=AS2GoTierung))" -SearchBase $DomainDN -Properties adminDescription -Server $Server -ErrorAction SilentlyContinue)
    foreach ($ou in $OUs) {
        Set-MigratedAdminDescription -Object $ou -Value $NewTag -ObjectTypeLabel "OU" -Counters $Counters
    }

    ################################################################################
    #####   2) Groups tagged only with the legacy exact adminDescription value #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Migrating AS2Go groups"
    $Groups = @(Get-ADGroup -LDAPFilter "(|(adminDescription=AS2GoAdmins)(adminDescription=AS2GoHelpDesk)(adminDescription=AS2GoVictims))" -SearchBase $DomainDN -Properties adminDescription -Server $Server -ErrorAction SilentlyContinue)
    foreach ($group in $Groups) {
        $NewGroupTag = "$($group.adminDescription)|$Scenario|ASP00|Create"
        Set-MigratedAdminDescription -Object $group -Value $NewGroupTag -ObjectTypeLabel "group" -Counters $Counters
    }

    ################################################################################
    #####   3) Users/computers tagged only with a legacy free-text Description #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Migrating AS2Go users and computers"
    $LegacyDescriptions = @(
        'AS2Go Demo User', 'AS2Go Lab Account', 'AS2Go Dummy User',
        'Tier 0 Device', 'Tier 1 Device', 'Tier 2 Device',
        'Tier 0 Service Account', 'Tier 1 Service Account', 'Tier 2 Service Account',
        'AS2Go Lab Computer - needed for Kerberoasting Attack'
    )
    $DescriptionFilter = ($LegacyDescriptions | ForEach-Object { "(description=$_)" }) -join ''
    $Principals = @(Get-ADObject -LDAPFilter "(&(|(objectClass=user)(objectClass=computer))(|$DescriptionFilter))" -SearchBase $DomainDN -Properties adminDescription -Server $Server -ErrorAction SilentlyContinue)
    foreach ($principal in $Principals) {
        Set-MigratedAdminDescription -Object $principal -Value $NewTag -ObjectTypeLabel "principal" -Counters $Counters
    }

    ################################################################################
    #####   4) AS2Go certificate templates tagged only with the legacy prefix  #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Migrating AS2Go certificate templates"
    try {
        $RootDC = Get-BestDomainController -Domain (Get-ADForest).RootDomain
        $ConfigNC = (Get-ADRootDSE -Server $RootDC).ConfigurationNamingContext
        $Templates = @(Get-ADObject -LDAPFilter "(&(objectClass=pKICertificateTemplate)(adminDescription=$Scenario*))" -SearchBase "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC" -Properties adminDescription -Server $RootDC -ErrorAction Stop)
        foreach ($template in $Templates) {
            if ($template.adminDescription -like "*|*|ASP00|*") {
                Write-AS2GoOutput -Type Info -Message "Certificate template '$($template.Name)' already carries the current tag; skipping." -NoExtraLines
                $Counters.Skipped++
                continue
            }
            $NewTemplateTag = "$($template.adminDescription)|$Scenario|ASP00|Create"
            if ($PSCmdlet.ShouldProcess($template.DistinguishedName, "Set adminDescription to '$NewTemplateTag'")) {
                try {
                    Set-ADObject -Identity $template.DistinguishedName -Replace @{ adminDescription = $NewTemplateTag } -Server $RootDC -ErrorAction Stop
                    Write-AS2GoOutput -Type Success -Message "Tagged certificate template '$($template.Name)'." -NoExtraLines
                    $Counters.Updated++
                }
                catch {
                    Write-AS2GoOutput -Type Warning -Message "Failed to tag certificate template '$($template.Name)': $_"
                }
            }
        }
    }
    catch {
        Write-AS2GoOutput -Type Warning -Message "Unable to query certificate templates for migration: $_"
    }

    ################################################################################
    #####   5) AD-Backup share (best effort; requires the configured server)   #####
    ################################################################################

    Write-AS2GoOutput -Type Header -Message "Migrating the AS2Go backup share"
    $ShareServer = Get-ASConfig -Setting "AS2GoAppServer"
    if (-not [string]::IsNullOrWhiteSpace($ShareServer)) {
        try {
            $ExistingDescription = Invoke-Command -ComputerName $ShareServer -ErrorAction Stop -ScriptBlock {
                (Get-SmbShare -Name "AD-Backup" -ErrorAction SilentlyContinue).Description
            }
            if ($ExistingDescription -and $ExistingDescription -notlike "*|*|ASP00|*") {
                if ($PSCmdlet.ShouldProcess("\\$ShareServer\AD-Backup", "Set share description to '$NewTag'")) {
                    Invoke-Command -ComputerName $ShareServer -ArgumentList $NewTag -ErrorAction Stop -ScriptBlock {
                        param($NewTag)
                        Set-SmbShare -Name "AD-Backup" -Description $NewTag -Force
                    }
                    Write-AS2GoOutput -Type Success -Message "Tagged backup share on '$ShareServer'." -NoExtraLines
                    $Counters.Updated++
                }
            }
            elseif ($ExistingDescription) {
                Write-AS2GoOutput -Type Info -Message "Backup share on '$ShareServer' already carries the current tag; skipping." -NoExtraLines
                $Counters.Skipped++
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Unable to migrate the backup share on '$ShareServer': $_"
        }
    }
    else {
        Write-AS2GoOutput -Type Info -Message "No backup share server is configured (AS2GoAppServer); skipping."
    }

    Write-AS2GoOutput -Type Success -Message "Finished migration. Tagged: $($Counters.Updated). Already current: $($Counters.Skipped)."
    Measure-FunctionRuntime -End -Details $info
}
