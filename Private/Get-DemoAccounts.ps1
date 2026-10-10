<#
.SYNOPSIS
Finds and displays AS2Go demo users in a domain.

.DESCRIPTION
Finds accounts marked as AS2Go demo users, reports their count, and displays selected account
details as examples.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Counts tagged demo accounts and displays a sample with selected account details.
#>
function Get-DemoAccounts {

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

    Invoke-Output -Type H1 -Message "`nOverview Demo Accounts"

    $results = Get-ADUser -Filter 'employeeType -like "AS2GoDemoUser"' `
        -Server $server `
        -SearchBase (Get-ADDomain).DistinguishedName `
        -ResultSetSize $null |
    Measure-Object | 
    Select-Object -ExpandProperty Count

    Invoke-Output -Type Bullet -Message "Identified Demo Accounts in the domain $((Get-ADDomain).DNSRoot)" -TM $results 

    If ($results -gt 0) {
        Invoke-Output -Type Bullet -Message "Here are some random example Accounts:"
        Get-ADUser -Filter 'employeeType -like "AS2GoDemoUser"' -Server $server -Properties * | Get-Random -Count 5 | Select-Object SamAccountName, enabled, Country, Department, CanonicalName | Format-Table -AutoSize | Out-Host
    }

    Write-Log -Message "    >> Found $results Demo Account "
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}