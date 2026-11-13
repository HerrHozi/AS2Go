<#
.SYNOPSIS
Finds AS2Go certificate templates by prefix.

.DESCRIPTION
Queries Active Directory for templates matching the supplied prefix and displays their names
and metadata.

.PARAMETER InventoryOnly
Displays the inventory without updating the AD CS setup state.

.PARAMETER ExactMatch
Matches CTPrefix as a complete template name.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Queries Active Directory for matching templates and displays their names and metadata.
#>
function Get-ADCSCertificateTemplates {

    ################################################################################
    #####                                                                      ##### 
    #####    Get all AS2GO specific certificate Templates                      #####                      
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
    $nameFilter = $escapedPrefix
    $matchDescription = "with prefix '$CTPrefix'"
    if ($ExactMatch) {
        $matchDescription = "named '$CTPrefix'"
    }
    else {
        $nameFilter += '*'
    }
    $templates = @(Get-ADObject -LDAPFilter "(&(objectClass=pKICertificateTemplate)(name=$nameFilter))" `
        -SearchBase "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"  `
        -Properties Name, whenChanged, CanonicalName   `
        -Server $Server)

    if (-not $InventoryOnly) {
        $Script:CTemplates = $templates
        $Script:ADCSASGoCTemplatesMissing = $templates.Count -eq 0
    }

    Write-AS2GoOutput -Type H1 -Message "Found $($templates.Count) certificate templates $matchDescription."

    if ($templates.Count -gt 0) {
        $templates | Select-Object Name, whenChanged, CanonicalName | Out-Host
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "No certificate templates $matchDescription were found."
    }
    
    $4logfile = $templates | Select-Object Name, whenChanged, CanonicalName | Format-Table | Out-String
    Write-Log -Message "    >> Identified the following AS2GO specific certificate Template withing Forest '$ConfigNC': $4logfile"
  
    Measure-FunctionRuntime -End -Details $Info
}
