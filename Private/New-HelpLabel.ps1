<#
.SYNOPSIS
Adds labels with unique accelerator keys to objects.

.DESCRIPTION
Uses the specified property as the label text and inserts an ampersand before its first
unused letter or digit other than S. Keys are case-insensitive and unique within one invocation.
Processes objects in input order, preserves their properties, and adds or replaces HelpLabel.
Reports an error if the property is missing, contains an ampersand, or has no available key.

.PARAMETER InputObject
Objects to extend, supplied directly as an array or through the pipeline.

.PARAMETER PropertyName
Property containing the label text, for example Username.

.EXAMPLE
$BestResults | New-HelpLabel -PropertyName 'Username'
Adds HelpLabel to each object using a unique accelerator from Username.

.OUTPUTS
System.Management.Automation.PSCustomObject. The input objects with HelpLabel added.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Adds HelpLabel from a specified property, using the first available case-insensitive letter or digit other than S as a unique key.
#>
function New-HelpLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject[]]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName
    )

    begin {
        $Info = Measure-FunctionRuntime -Begin
        $UsedKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    process {
        foreach ($Object in $InputObject) {
            $Property = $Object.PSObject.Properties[$PropertyName]
            if ($null -eq $Property) {
                throw "The input object does not contain property '$PropertyName'."
            }

            $Label = [string]$Property.Value
            if ($Label.Contains('&')) {
                throw "Property '$PropertyName' must not contain an ampersand."
            }

            $KeyIndex = -1
            for ($Index = 0; $Index -lt $Label.Length; $Index++) {
                if ([char]::IsLetterOrDigit($Label[$Index]) -and
                    [char]::ToUpperInvariant($Label[$Index]) -ne [char]'S' -and
                    $UsedKeys.Add([string]$Label[$Index])) {
                    $KeyIndex = $Index
                    break
                }
            }

            if ($KeyIndex -lt 0) {
                throw "No unused accelerator key is available for '$Label' in property '$PropertyName'."
            }

            $Object | Add-Member -MemberType NoteProperty -Name HelpLabel -Value $Label.Insert($KeyIndex, '&') -Force -PassThru
        }
    }

    end {
        Measure-FunctionRuntime -End -Details $Info
    }
}