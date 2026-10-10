<#
.SYNOPSIS
Finds AS2Go certificate templates by prefix.

.FUNCTIONALITY
Queries Active Directory for matching templates and displays their names and metadata.
#>
function Get-ADCSCertifcateTemplates {

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
        [string] $CTPrefix
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $ConfigNC = (Get-ADRootDSE).ConfigurationNamingContext
    $script:CTemplates = Get-ADObject -LDAPFilter "(&(objectClass=pKICertificateTemplate)(name=$CTPrefix*))" `
        -SearchBase "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"  `
        -Properties Name, whenChanged, CanonicalName   `
        -Server $Server

    Invoke-Output -Type H1 -Message "`n`nIdentitfied $($script:CTemplates.count) 'AS2Go' Certificate Templates"

    If ($null -ne $script:CTemplates ) {
        $script:CTemplates | Select-Object Name, @{N = 'whenChanged'; E = { $_.whenChanged } }, @{N = 'CanonicalName'; E = { $_.CanonicalName } } | out-host
        $Script:ADCSASGoCTemplatesMissing = $false
    }
    else {
        #Invoke-Output -Type Info -Message "No AS2GO specific certificate Templates found."
    }
    
    $4logfile = $script:CTemplates | Select-Object Name, @{N = 'whenChanged'; E = { $_.whenChanged } }, @{N = 'CanonicalName'; E = { $_.CanonicalName } } | Format-Table | out-string 
    Write-Log -Message "    >> Identified the following AS2GO specific certificate Template withing Forest '$ConfigNC': $4logfile"
  
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
