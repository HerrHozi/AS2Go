function Get-ADCSComponents {

    ################################################################################
    #####                                                                      ##### 
    #####    Find possible CA & Enrollment services                               
    #####                                                                      #####
    ################################################################################

    Param([string] $param1, [string] $param2)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $script:EnrollmentServices = @()
    $script:RootCA = @()
    $script:As2GoTemplates = @()

    $config = (Get-ADRootDSE).ConfigurationNamingContext
    $enrollDN = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$config"
    $RootCADN = "CN=Certification Authorities,CN=Public Key Services,CN=Services,$config"
    $CTemplateDN = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$config"

    $script:EnrollmentServices = Get-ADObject -SearchBase $enrollDN -LDAPFilter "(objectClass=pKIEnrollmentService)" -Properties Name, dNSHostName, CanonicalName 
    $script:RootCA = Get-ADObject -SearchBase $RootCADN -LDAPFilter "(objectClass=certificationAuthority)" -Properties Name, dNSHostName, CanonicalName 
    $script:CTemplates = Get-ADObject -SearchBase $CTemplateDN -LDAPFilter "(&(objectClass=pKICertificateTemplate)(Name=AS2GO*))" -Properties Name, whenChanged, CanonicalName 

    "Enrollment Services: $($script:EnrollmentServices.Count)"
    $script:EnrollmentServices | Select-Object Name, @{N = 'Host'; E = { $_.dNSHostName } }, @{N = 'CanonicalName'; E = { $_.CanonicalName } }

    "Certification Authorities: $($script:RootCA.Count)"
    $script:RootCA | Select-Object Name, @{N = 'Host'; E = { $_.dNSHostName } }, @{N = 'CanonicalName'; E = { $_.CanonicalName } }

    "AS2Go Certificate Templates: $($script:CTemplates.Count)"
    $script:CTemplates | Select-Object Name, @{N = 'whenChanged'; E = { $_.whenChanged } }, @{N = 'CanonicalName'; E = { $_.CanonicalName } }



    $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
    $ConfigurationPartition = $rootDSE.configurationNamingContext

    $CertificationAuthoritiesPath = "CN=Certification Authorities,CN=Public Key Services,CN=Services,$ConfigurationPartition"
    $CertificationAuthorities = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$CertificationAuthoritiesPath")
    $CertificationAuthorities.Children

    

    $EnrollmentServicesPath = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigurationPartition"
    $EnrollmentServicesPath = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$EnrollmentServicesPath")
    $EnrollmentServicesPath.Children


    $CertificateTemplatesPath = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigurationPartition"
    $CertificateTemplates = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$CertificateTemplatesPath")
    $CertificateTemplates.Children


    $config = (Get-ADRootDSE).ConfigurationNamingContext
    $ADCS = Get-ADObject -Filter "ObjectClass -eq 'pKIEnrollmentService' -or ObjectClass -eq 'certificationAuthority'" -SearchBase "CN=Public Key Services,CN=Services,$config"
    $ADCS = $ADCS | Select-Object ObjectClass, Name, @{N = 'CanonicalName'; E = { Convert-FromDNToCN -DistinguishedName $_.DistinguishedName } }, ObjectGUID
    $4logfile = $ADCS | Out-String
    Write-Log -Message "    >> Identified the following ADCS roles: $4logfile"

    $Script:ADCS["EnrollmentService"] = $ADCS | Where-Object { $_.ObjectClass -eq 'pKIEnrollmentService' } | select-object -ExpandProperty 'CanonicalName'
    $Script:ADCS["certificationAuthority"] = $ADCS | Where-Object { $_.ObjectClass -eq 'certificationAuthority' -and $_.CanonicalName -notmatch '/AIA|/NTAuthCertificates' } | select-object -ExpandProperty 'CanonicalName'

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
