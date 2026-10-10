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

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type H1 -Message "`nOverview AS2Go Assets"

    $results = Get-ADOrganizationalUnit -Filter 'postalCode -like "AS2GOTierung"' `
        -Server $server `
        -SearchBase (Get-ADDomain).DistinguishedName `
        -ResultSetSize $null |
    Measure-Object | 
    Select-Object -ExpandProperty Count

    Invoke-Output -Type Bullet -Message "Identified AS2Go Assests in the domain $((Get-ADDomain).DNSRoot)" -TM $results 

    If ($results -gt 0) {
        Invoke-Output -Type Bullet -Message "Here is an example:"
        Get-ADOrganizationalUnit -Filter 'postalCode -like "AS2GOTierung"' -Server $server -Properties * | Select-Object CanonicalName, Description | Sort-Object  CanonicalName | Format-Table -AutoSize | Out-Host
    }

    Write-Log -Message "    >> Found $results Demo Account "
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}