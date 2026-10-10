<#
.SYNOPSIS
Finds and displays AS2Go security groups in a domain.

.FUNCTIONALITY
Counts groups tagged as AS2Go admins, helpdesk, or victims and shows examples.
#>
function Get-AS2GoGroups {

    ################################################################################
    #####                                                                      ##### 
    #####    Find AS2Go Groups based on AS2GoAdmins Group Name Pattern        #####                               
    #####                                                                      #####
    ################################################################################

    Param([Parameter(Mandatory)][string]$Server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type H1 -Message "`nOverview AS2Go Groups"

    $results = Get-ADGroup -Filter 'adminDescription -like "AS2GoAdmins" -or adminDescription -like "AS2GoHelpDesk" -or adminDescription -like "AS2GoVictims"' `
        -Server $server `
        -SearchBase (Get-ADDomain).DistinguishedName `
        -ResultSetSize $null |
    Measure-Object | 
    Select-Object -ExpandProperty Count

    Invoke-Output -Type Bullet -Message "Identified AS2Go Groups in the domain $((Get-ADDomain).DNSRoot)" -TM $results 

    If ($results -gt 0) {
        Invoke-Output -Type Bullet -Message "Here is an example:"
        Get-ADGroup -Filter 'adminDescription -like "AS2GoAdmins" -or adminDescription -like "AS2GoHelpDesk" -or adminDescription -like "AS2GoVictims"' -Server $server -Properties * | Select-Object Name, Description | Sort-Object  Name | Format-Table -AutoSize | Out-Host
    }

    Write-Log -Message "    >> Found $results AS2Go Groups "
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}