<#
.SYNOPSIS
Creates and publishes a new ESC1 and ESC4 certificate template pair.

.DESCRIPTION
Builds one ESC1-vulnerable and one ESC4-writable certificate template with lab-hardened properties
and permissions, using unique template OIDs and shared timestamped names. Offers an Enterprise CA
when several are registered, creates both templates in the Certificate Templates container, grants
Authenticated Users enrollment (ESC1) or full write access (ESC4), and publishes both templates to
the selected CA. Existing templates are never modified and CA settings are not changed.

.PARAMETER CTPrefix
Prefix for the internal template names. The default prefix is AS2Go.

.PARAMETER Suffix
Optional suffix for the internal template names. Without it, a shared timestamp is used.

.PARAMETER EnrollmentCA
Optional Enterprise CA given as distinguished name or as dNSHostName\cn. Without it, a selection
menu appears when several CAs are registered.

.PARAMETER Server
Domain controller for directory operations. Defaults to the preferred forest root controller.

.EXAMPLE
New-ESCxCertficateTemplate -CTPrefix AS2Go
Creates a new ESC1 and ESC4 template pair and offers an Enterprise CA for publication.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
System.Boolean. $true when both templates were created, permissioned, and published; otherwise $false.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session with Enterprise Admin rights
in an explicitly authorized lab environment. Creates template objects, template permissions, and
CA publication entries.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Creates a new ESC1 and ESC4 certificate template pair with unique OIDs and publishes both to a selected Enterprise CA.
#>
function New-ESCxCertficateTemplate {

    ################################################################################
    #####                                                                      #####
    #####    Create and publish new ESC1 and ESC4 certificate templates       #####
    #####                                                                      #####
    ################################################################################

    [CmdletBinding()]
    Param(
        [string] $CTPrefix = "AS2Go",
        [string] $Suffix,
        [string] $EnrollmentCA,
        [string] $Server
    )

    $Info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Create and Publish ESC1 and ESC4 Certificate Templates"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -Message "ESC1 - Authenticated Users can enroll while supplying an arbitrary subject (ENROLLEE_SUPPLIES_SUBJECT, Client Authentication EKU)."
    Write-AS2GoOutput -Type Bullet -Message "ESC4 - Authenticated Users hold write access to the template object; created without ESC1-vulnerable properties."


    If ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Get-BestDomainController -Domain (Get-ADForest).RootDomain
    }

    If ([string]::IsNullOrWhiteSpace($CTPrefix)) {
        $CTPrefix = "AS2Go"
    }
    elseif ($CTPrefix.Trim() -match '[^A-Za-z0-9._-]') {
        Write-AS2GoOutput -Type Warning -Message "Prefix '$CTPrefix' contains unsupported characters for internal template names; the default prefix AS2Go is used instead."
        $CTPrefix = "AS2Go"
    }

    $TimeStamp = Get-Date -Format $Script:DateFormatSA
    $NameSuffix = (Get-Date).ToString('yyyyMMdd-HHmmss')
    If (-not [string]::IsNullOrWhiteSpace($Suffix)) {
        If ($Suffix.Trim() -match '[^A-Za-z0-9._-]') {
            Write-AS2GoOutput -Type Warning -Message "Suffix '$Suffix' contains unsupported characters for internal template names; the timestamp is used instead."
        }
        else {
            $NameSuffix = $Suffix.Trim()
        }
    }

    $Esc1OID = '1.3.6.1.4.1.311.21.8.' + ((1..8 | ForEach-Object { Get-Random -Minimum 1 -Maximum 9999999 }) -join '.') + '.' + (Get-Random -Minimum 1 -Maximum 99)
    $Esc4OID = '1.3.6.1.4.1.311.21.8.' + ((1..8 | ForEach-Object { Get-Random -Minimum 1 -Maximum 9999999 }) -join '.') + '.' + (Get-Random -Minimum 1 -Maximum 99)

    $TemplateSpecs = @(
        @{
            Esc         = 'ESC1'
            Name        = "$CTPrefix-ESC1-$NameSuffix"
            DisplayName = "ESC1 - $NameSuffix"
            AdminDescription = "AS2Go ESC1|$CTPrefix|ASP00|Create"
            Description = "AS2Go ESC1 lab template - ENROLLEE_SUPPLIES_SUBJECT with Client Authentication EKU; enrolled by Authenticated Users."
            EnrollAce   = $true
            Properties  = @{
                flags                                  = 131642
                'msPKI-Certificate-Application-Policy' = @('1.3.6.1.4.1.311.10.3.4', '1.3.6.1.5.5.7.3.4', '1.3.6.1.5.5.7.3.2')
                'msPKI-Certificate-Name-Flag'          = 1
                'msPKI-Cert-Template-OID'              = $Esc1OID
                'msPKI-Enrollment-Flag'                = 9
                'msPKI-Minimal-Key-Size'               = 2048
                'msPKI-Private-Key-Flag'               = 16842768
                'msPKI-RA-Signature'                   = 0
                'msPKI-Template-Minor-Revision'        = 2
                'msPKI-Template-Schema-Version'        = 2
                pKICriticalExtensions                  = @('2.5.29.15', '2.5.29.7')
                pKIDefaultCSPs                         = @('1,Microsoft Enhanced Cryptographic Provider v1.0', '2,Microsoft Base Cryptographic Provider v1.0')
                pKIDefaultKeySpec                      = 1
                pKIExpirationPeriod                    = [byte[]](0x00, 0x40, 0x39, 0x87, 0x2E, 0xE1, 0xFE, 0xFF)
                pKIExtendedKeyUsage                    = @('1.3.6.1.4.1.311.10.3.4', '1.3.6.1.5.5.7.3.4', '1.3.6.1.5.5.7.3.2')
                pKIKeyUsage                            = [byte[]](0xA0, 0x00)
                pKIMaxIssuingDepth                     = 0
                pKIOverlapPeriod                       = [byte[]](0x00, 0x80, 0xA6, 0x0A, 0xFF, 0xDE, 0xFF, 0xFF)
                revision                               = 100
            }
        },
        @{
            Esc         = 'ESC4'
            Name        = "$CTPrefix-ESC4-$NameSuffix"
            DisplayName = "ESC4 - $NameSuffix"
            AdminDescription = "AS2Go ESC4|$CTPrefix|ASP00|Create"
            Description = "AS2Go ESC4 lab template - Authenticated Users have write access to the template object; it is not ESC1-vulnerable as created."
            EnrollAce   = $false
            Properties  = @{
                flags                                  = 131616
                'msPKI-Cert-Template-OID'              = $Esc4OID
                'msPKI-Certificate-Application-Policy' = '1.3.6.1.5.5.7.3.3'
                'msPKI-Certificate-Name-Flag'          = -2113929216
                'msPKI-Enrollment-Flag'                = 32
                'msPKI-Minimal-Key-Size'               = 2048
                'msPKI-Private-Key-Flag'               = 16842752
                'msPKI-RA-Signature'                   = 0
                'msPKI-Template-Minor-Revision'        = 2
                'msPKI-Template-Schema-Version'        = 2
                pKICriticalExtensions                  = '2.5.29.15'
                pKIDefaultCSPs                         = @('3,Microsoft Base DSS Cryptographic Provider', '2,Microsoft Base Cryptographic Provider v1.0', '1,Microsoft Enhanced Cryptographic Provider v1.0')
                pKIDefaultKeySpec                      = 2
                pKIExpirationPeriod                    = [byte[]](0x00, 0x40, 0x39, 0x87, 0x2E, 0xE1, 0xFE, 0xFF)
                pKIExtendedKeyUsage                    = '1.3.6.1.5.5.7.3.3'
                pKIKeyUsage                            = [byte[]](0xA0, 0x00)
                pKIMaxIssuingDepth                     = 0
                pKIOverlapPeriod                       = [byte[]](0x00, 0x80, 0xA6, 0x0A, 0xFF, 0xDE, 0xFF, 0xFF)
                revision                               = 100
            }
        }
    )

    # Verify the new names are free; existing templates are never modified or cleaned up.
    $existingNames = @()
    foreach ($spec in $TemplateSpecs) {
        $existing = Get-ADObject -Filter "(objectClass -eq 'pKICertificateTemplate' -and name -eq '$($spec.Name)')" -Server $Server -ErrorAction SilentlyContinue
        if ($existing) { $existingNames += $spec.Name }
    }
    If ($existingNames.Count -gt 0) {
        Write-AS2GoOutput -Type Error -Message "Certificate template(s) with the same name already exist: $($existingNames -join ', '). Start the creation again later or use a different suffix; existing templates are not modified."
        Measure-FunctionRuntime -End -Details $Info
        return $false
    }


    #region select Enterprise CA
    $ConfigNC = (Get-ADRootDSE -Server $Server).ConfigurationNamingContext
    $enrollmentServices = Get-ADObject -LDAPFilter "(objectClass=pKIEnrollmentService)" `
        -SearchBase "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigNC" `
        -Properties Name, dNSHostName, certificateTemplates `
        -Server $Server

    If (-not $enrollmentServices) {
        Write-AS2GoOutput -Type Error -Message "No Enterprise CA (pKIEnrollmentService) was found. Run the AD&CS setup before creating certificate templates."
        Measure-FunctionRuntime -End -Details $Info
        return $false
    }
    $enrollmentServices = @($enrollmentServices | Sort-Object -Property Name)

    If (-not [string]::IsNullOrWhiteSpace($EnrollmentCA)) {
        $selectedCA = $enrollmentServices | Where-Object {
            $_.DistinguishedName -eq $EnrollmentCA -or
            [string]$EnrollmentCA -eq "$($_.dNSHostName)\$($_.Name)"
        } | Select-Object -First 1
        If (-not $selectedCA) {
            Write-AS2GoOutput -Type Error -Message "No Enterprise CA matching '$EnrollmentCA' was found. Register the CA first or pass its distinguished name or dNSHostName\cn."
            Measure-FunctionRuntime -End -Details $Info
            return $false
        }
    }
    elseif ($enrollmentServices.Count -gt 1) {
        $caMenu = $enrollmentServices | Select-Object Name,
            @{N = 'CAHelp'; E = { $templateCount = 0; If ($_.certificateTemplates) { $templateCount = @($_.certificateTemplates).Count }; "$($_.dNSHostName) - $templateCount published templates" } },
            DistinguishedName
        $caOptions = @($caMenu | New-HelpOptions -Label 'Name' -Help 'CAHelp' -Value 'DistinguishedName')
        $selectedCAKey = Show-DecisionPrompt -Title "Select the Enterprise CA for publishing the new templates" `
            -Message "Both ESC1 and ESC4 templates are published to one CA." `
            -Options $caOptions -Default 0
        $selectedCA = $enrollmentServices | Where-Object { $_.DistinguishedName -eq $selectedCAKey } | Select-Object -First 1
    }
    else {
        $selectedCA = $enrollmentServices[0]
        Write-AS2GoOutput -Type Info -Message "Publishing to the only Enterprise CA: $($selectedCA.dNSHostName)\$($selectedCA.Name)"
    }
    #endregion select Enterprise CA


    #region create templates
    $templatesContainer = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"

    # Principals and ACE parts for the new template permissions.
    $authenticatedUsers = [System.Security.Principal.SecurityIdentifier]'S-1-5-11'
    $enrollGuid = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
    $allPropertiesGuid = [guid]'00000000-0000-0000-0000-000000000000'
    $allow = [System.Security.AccessControl.AccessControlType]::Allow

    foreach ($spec in $TemplateSpecs) {
        Write-AS2GoOutput -Type TextMaker -Message "Creating $($spec.Esc) template:" -Tm $spec.Name -NoExtraLines
        try {
            # Create the blank template object.
            $templatePath = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Server/$templatesContainer")
            $newTemplate = $templatePath.Children.Add("CN=$($spec.Name)", 'pKICertificateTemplate')
            $newTemplate.CommitChanges()
            $templateDn = "CN=$($spec.Name),$templatesContainer"

            # Apply the template properties with ActiveDirectory (ADWS);
            # ADSI commits on freshly created objects can fail with 0x80072030.
            $attributes = @{ displayName = $spec.DisplayName; adminDescription = $spec.AdminDescription; description = $spec.Description }
            foreach ($property in $spec.Properties.GetEnumerator()) {
                $attributes[$property.Key] = $property.Value
            }
            Set-ADObject -Identity $templateDn -Add $attributes -Server $Server -ErrorAction Stop

            # Apply the template permissions with ActiveDirectory (ADWS).
            $aclEntry = Get-ADObject -Identity $templateDn -Server $Server -Properties nTSecurityDescriptor -ErrorAction Stop
            $acl = $aclEntry.nTSecurityDescriptor
            If ($spec.EnrollAce) {
                $acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($authenticatedUsers, [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight, $allow, $enrollGuid)))
                $acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($authenticatedUsers, [System.DirectoryServices.ActiveDirectoryRights]::GenericRead, $allow, $allPropertiesGuid)))
            }
            else {
                $acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($authenticatedUsers, [System.DirectoryServices.ActiveDirectoryRights]::GenericAll, $allow, $allPropertiesGuid)))
            }
            Set-ADObject -Identity $templateDn -Replace @{ nTSecurityDescriptor = $acl } -Server $Server -ErrorAction Stop

            #Write-AS2GoOutput -Type Success -Message "$($spec.Esc) template '$($spec.Name)' created (OID $($spec.Properties['msPKI-Cert-Template-OID']))."
        }
        catch {
            Write-AS2GoOutput -Type Error -Message "Failed to create the $($spec.Esc) template '$($spec.Name)': $($_.Exception.Message)"
            Measure-FunctionRuntime -End -Details $Info
            return $false
        }
    }
    #endregion create templates


    #region publish templates
    try {
        $caObject = Get-ADObject -Identity $selectedCA.DistinguishedName -Server $Server -Properties certificateTemplates -ErrorAction Stop
        $publishedNames = @($caObject.certificateTemplates | ForEach-Object { [string]$_ })
        $missingNames = @($TemplateSpecs | Where-Object { $publishedNames -notcontains $_.Name } | ForEach-Object Name)

        If ($missingNames.Count -gt 0) {
            Write-AS2GoOutput -Type Textmaker -Message "Publishing ESC1 and ESC4 templates on CA" -tm "'$($selectedCA.Name)' ($($selectedCA.dNSHostName))." -NoExtraLines
            Set-ADObject -Identity $selectedCA.DistinguishedName -Add @{ certificateTemplates = [string[]]$missingNames } -Server $Server -ErrorAction Stop

        }
        else {
            Write-AS2GoOutput -Type Info -Message "Both templates are already published on CA '$($selectedCA.Name)'."
        }
    }
    catch {
        Write-AS2GoOutput -Type Error -Message "Failed to publish the templates on CA '$($selectedCA.Name)': $($_.Exception.Message)"
        Measure-FunctionRuntime -End -Details $Info
        return $false
    }
    #endregion publish templates


    $createdTemplates = foreach ($spec in $TemplateSpecs) {
        Get-ADObject -LDAPFilter "(&(objectClass=pKICertificateTemplate)(name=$($spec.Name)))" `
            -SearchBase $templatesContainer `
            -Properties Name, displayName, msPKI-Cert-Template-OID, whenCreated `
            -Server $Server
    }

    Write-AS2GoOutput -Type H1 -Message "`nNew ESC1 and ESC4 certificate templates"
    $createdTemplates | Select-Object Name, displayName, msPKI-Cert-Template-OID, whenCreated | Out-Host

    $4logfile = $createdTemplates | Select-Object Name, displayName, msPKI-Cert-Template-OID, whenCreated | Format-Table | Out-String
    Write-Log -Message "    >> Created and published AS2Go certificate templates: $4logfile"

    Measure-FunctionRuntime -End -Details $Info
    return $true
}
