<#
.SYNOPSIS
Finds AS2Go certificate templates by the adminDescription marker.

.DESCRIPTION
Queries Active Directory for templates whose adminDescription starts with the supplied prefix and
displays their names and metadata. New-ESCxCertficateTemplate writes the AS2Go marker in
adminDescription (for example "AS2Go ESC1"), which is the sole search criterion.

.PARAMETER InventoryOnly
Displays the inventory without updating the AD CS setup state.

.PARAMETER ExactMatch
Matches adminDescription as a complete value.

.PARAMETER CTPrefix
Marker prefix in adminDescription. Defaults to AS2Go.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Queries Active Directory for templates with a matching adminDescription marker and displays names and metadata.
#>
function Get-ADCSCertificateTemplates {

    ################################################################################
    #####                                                                      ##### 
    #####    Get all AS2Go specific certificate Templates                      #####                      
    #####                                                                      #####
    ################################################################################

    Param
    (
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$Server,
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $CTPrefix,
        [switch] $InventoryOnly,
        [switch] $ExactMatch
    )

    $Info = Measure-FunctionRuntime -Begin

    $ConfigNC = (Get-ADRootDSE -Server $Server).ConfigurationNamingContext
    $escapedPrefix = $CTPrefix.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
    $matchDescription = "with adminDescription prefix '$CTPrefix'"
    if ($ExactMatch) {
        # Matches the legacy exact value and the current tagged value (Name|Scenario|ASP00|Create).
        $adminDescriptionClause = "(|(adminDescription=$escapedPrefix)(adminDescription=$escapedPrefix|*))"
        $matchDescription = "with adminDescription '$CTPrefix'"
    }
    else {
        $adminDescriptionClause = "(adminDescription=$escapedPrefix*)"
    }
    $templates = @(Get-ADObject -LDAPFilter "(&(objectClass=pKICertificateTemplate)$adminDescriptionClause)" `
        -SearchBase "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"  `
        -Properties Name, adminDescription, whenChanged, CanonicalName   `
        -Server $Server)

    if (-not $InventoryOnly) {
        $Script:CTemplates = $templates
        $Script:ADCSASGoCTemplatesMissing = $templates.Count -eq 0
    }

    Write-AS2GoOutput -Type H1 -Message "Found $($templates.Count) certificate templates $matchDescription."

    if ($templates.Count -gt 0) {
        $templates | Select-Object Name, adminDescription, whenChanged, CanonicalName | Out-Host
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "No certificate templates $matchDescription were found."
    }
    
    $4logfile = $templates | Select-Object Name, adminDescription, whenChanged, CanonicalName | Format-Table | Out-String
    Write-Log -Message "    >> Identified the following AS2Go specific certificate Template withing Forest '$ConfigNC': $4logfile"
  
    Measure-FunctionRuntime -End -Details $Info
}
