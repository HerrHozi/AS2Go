<#
.SYNOPSIS
Captures the explicitly supplied parameters of a function call.

.DESCRIPTION
Creates a snapshot of the calling function's bound parameter names and values.
Omitted parameters are not included; explicitly supplied false switch values are preserved.

.COMPONENT
Category: Sub Function
#>
function Get-FunctionCallParameters {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $FunctionName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.IDictionary] $BoundParameters
    )

    $parameters = @{}
    foreach ($name in $BoundParameters.Keys) {
        $parameters[$name] = $BoundParameters[$name]
    }

    [pscustomobject]@{
        FunctionName = $FunctionName
        Parameters   = $parameters
    }
}
