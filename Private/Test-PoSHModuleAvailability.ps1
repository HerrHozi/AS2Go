<#
.SYNOPSIS
    Tests whether a PowerShell module is available and imports it if found.

.DESCRIPTION
    Returns `$true` when the specified PowerShell module is available and
    successfully imported. Returns `$false` when the module is unavailable
    or cannot be imported.

.COMPONENT
    Category: Sub Function

.FUNCTIONALITY
    Checks for and imports the requested PowerShell module.
#>
function Test-PoSHModuleAvailability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PSModule
    )

    $Info = Measure-FunctionRuntime -Begin

    $result = $false

    try {
        if (-not (Get-Module -ListAvailable -Name $PSModule -SkipEditionCheck)) {
            if ($PSModule -eq 'GroupPolicy') {
                Invoke-Output -Type Warning -M "The '$PSModule' PowerShell module is not installed."
            }
            else {
                Invoke-Output -Type Error -M "The '$PSModule' PowerShell module is not installed."
            }

            return $false
        }

        Import-Module -Name $PSModule -SkipEditionCheck -ErrorAction Stop

        Invoke-Output -Type Bullet -M 'Imported PowerShell module: ' -TM $PSModule

        $result = $true
    }
    catch {
        Invoke-Output -Type Error -M "Failed to import the '$PSModule' PowerShell module." -TM $_.Exception.Message
        $result = $false
    }
    finally {
        Measure-FunctionRuntime -End -Details $Info
    }

    return $result
}