<#
.SYNOPSIS
Checks whether a PowerShell module is installed and imports it when available.

.DESCRIPTION
Checks for the requested module, imports it when available, and returns a pass or fail result.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Returns passed or failed after checking and importing the requested module.
#>
function Confirm-PoSHModuleAvailabliy {

    Param([string]$PSModule)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    [string] $result = "passed"

    If ($null -eq (Get-Module -ListAvailable -Name $PSModule)) {

        If ("GroupPolicy" -eq $PSModule) {
            Invoke-Output -Type  Warning -M "The '$PSModule' PowerShell module is not installed."
        }
        else {
            Invoke-Output -Type  Error -M "The '$PSModule' PowerShell module is not installed."
        }

        $result = "failed"
    }
    else {
        Import-Module $PSModule
        Invoke-Output -Type  Bullet -M "Imported PowerShell module: " -TM $PSModule
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
    return $result
}
