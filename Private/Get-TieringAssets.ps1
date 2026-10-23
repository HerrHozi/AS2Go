<#
.SYNOPSIS
Finds and displays AS2Go tiering organizational units.

.DESCRIPTION
Finds OUs marked as AS2Go tier assets, reports their count, and displays example paths and
descriptions.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Counts OUs tagged as AS2Go tier assets and displays example paths and descriptions.
#>
function Get-TieringAssets {

    ################################################################################
    #####                                                                      ##### 
    #####    Find Demo Accounts based on AS2GoDemoUser Account Name Pattern    #####                               
    #####                                                                      #####
    ################################################################################

    Param([Parameter(Mandatory)][string]$Server)

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type H1 -Message "`nOverview AS2Go Assets"

    $results = Get-ADOrganizationalUnit -Filter 'postalCode -like "AS2GOTierung"' `
        -Server $server `
        -SearchBase (Get-ADDomain).DistinguishedName `
        -ResultSetSize $null |
    Measure-Object | 
    Select-Object -ExpandProperty Count

    Write-AS2GoOutput -Type Bullet -Message "Identified AS2Go Assests in the domain $((Get-ADDomain).DNSRoot)" -TM $results 

    If ($results -gt 0) {
        Write-AS2GoOutput -Type Bullet -Message "Here is an example:"
        Get-ADOrganizationalUnit -Filter 'postalCode -like "AS2GOTierung"' -Server $server -Properties * | Select-Object CanonicalName, Description | Sort-Object  CanonicalName | Format-Table -AutoSize | Out-Host
    }

    Write-Log -Message "    >> Found $results Demo Account "
    Measure-FunctionRuntime -End -Details $Info
}