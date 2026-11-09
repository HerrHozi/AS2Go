<#
.SYNOPSIS
Creates decision prompt options from object properties.

.DESCRIPTION
Builds options with accelerator labels, help text, and values selected from the input objects.
Use -Value IndexOf to use each object's zero-based position as its option value.

.PARAMETER InputObject
Objects to convert, supplied directly as an array or through the pipeline.

.PARAMETER Label
Property containing the text used to create each option label.

.PARAMETER Help
Property containing the help text for each option.

.PARAMETER Value
Property containing each option's return value, or IndexOf for its zero-based position.

.PARAMETER AddSkip
Adds a final Skip option whose value is $Script:No.

.EXAMPLE
$Files | New-HelpOptions -Label Name -Help LastWriteTime -Value FullName
Creates options labeled from each file name, with the last-write time as help and full path as value.

.OUTPUTS
System.Management.Automation.PSCustomObject. Options with Label, Help, and Value properties.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Creates decision prompt options from object properties, with unique accelerator labels and selectable return values.
#>
function New-HelpOptions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Help,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [switch]$AddSkip
    )

    begin {
        $Info = Measure-FunctionRuntime -Begin
        $Objects = [System.Collections.Generic.List[object]]::new()
    }

    process {
        $Objects.Add($InputObject)
    }

    end {
        $LabeledObjects = @($Objects.ToArray() | New-HelpLabel -PropertyName $Label)
        $UseIndex = [string]::Equals($Value, 'IndexOf', [System.StringComparison]::OrdinalIgnoreCase)

        for ($Index = 0; $Index -lt $LabeledObjects.Count; $Index++) {
            $Object = $LabeledObjects[$Index]
            $HelpProperty = $Object.PSObject.Properties[$Help]
            if ($null -eq $HelpProperty) {
                throw "The input object does not contain help property '$Help'."
            }

            if ($UseIndex) {
                $OptionValue = $Index
            }
            else {
                $ValueProperty = $Object.PSObject.Properties[$Value]
                if ($null -eq $ValueProperty) {
                    throw "The input object does not contain value property '$Value'."
                }

                $OptionValue = $ValueProperty.Value
            }

            [pscustomobject]@{
                Label = $Object.HelpLabel
                Help  = $HelpProperty.Value
                Value = $OptionValue
            }
        }

        if ($AddSkip) {
            [pscustomobject]@{
                Label = '&Skip'
                Help  = 'Skip this selection'
                Value = $Script:No
            }
        }

        Measure-FunctionRuntime -End -Details $Info
    }
}
