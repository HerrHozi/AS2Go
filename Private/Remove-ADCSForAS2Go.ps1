<#
.SYNOPSIS
Removes AS2Go certificate templates and decommissions the AS2Go Certification Authority.

.DESCRIPTION
Removes every certificate template tagged with the supplied adminDescription prefix, then
decommissions the AS2GoRootCA: removes its Enrollment Services, AIA, CDP, and Certification
Authorities entries under CN=Public Key Services,CN=Services,CN=Configuration, and uninstalls the
ADCS-Cert-Authority and ADCS-Web-Enrollment Windows features from the root-domain controller.

.PARAMETER CTPrefix
Marker prefix used to find AS2Go certificate templates by adminDescription. Defaults to AS2Go.

.NOTES
NTAuthCertificates is not modified by this function: removing a CA certificate from that store
requires matching the exact certificate binary to avoid affecting other, unrelated CAs trusted for
client authentication. Verify and clean up NTAuthCertificates manually if required.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Removes AS2Go-tagged certificate templates, cleans up the AS2GoRootCA AD CS configuration objects,
and uninstalls the Certification Authority and Web Enrollment Windows features.
#>
function Remove-ADCSForAS2Go {

    param(
        [string] $CTPrefix = "AS2Go"
    )

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Removing AS2Go AD CS configuration"

    $RootDC = Get-BestDomainController -Domain (Get-ADForest).RootDomain
    $CAName = "AS2GoRootCA"

    ################################################################################
    #####   1) Remove AS2Go certificate templates                             #####
    ################################################################################

    # Not -InventoryOnly: Get-ADCSCertificateTemplates only populates $Script:CTemplates in that mode.
    Get-ADCSCertificateTemplates -CTPrefix $CTPrefix -Server $RootDC
    $Templates = @($Script:CTemplates)

    if ($Templates.Count -eq 0) {
        Write-AS2GoOutput -Type Info -Message "No AS2Go certificate templates were found."
    }
    else {
        $Options = @(
            [pscustomobject] @{ Label = "&Yes"; Help = "Delete $($Templates.Count) certificate template(s)."; Value = $Script:Yes },
            [pscustomobject] @{ Label = "&No"; Help = "Skip deleting certificate templates."; Value = $Script:No }
        )
        $answer = Show-DecisionPrompt -Message "Remove $($Templates.Count) AS2Go certificate template(s)?" -Options $Options -Default 1

        if ($answer -eq $Script:Yes) {
            foreach ($Template in $Templates) {
                try {
                    Invoke-Command -ComputerName $RootDC -ArgumentList $Template.Name -ErrorAction SilentlyContinue -ScriptBlock {
                        param($Name)
                        certutil -CATemplates "-$Name" 2>&1 | Out-Null
                    }
                }
                catch {
                    Write-AS2GoOutput -Type Warning -Message "Could not unpublish template '$($Template.Name)' from the CA (it may not have been published): $_"
                }
                try {
                    Remove-ADObject -Identity $Template.DistinguishedName -Server $RootDC -Confirm:$false -ErrorAction Stop
                    Write-AS2GoOutput -Type Success -Message "Removed certificate template '$($Template.Name)'." -NoExtraLines
                }
                catch {
                    Write-AS2GoOutput -Type Warning -Message "Failed to remove certificate template '$($Template.Name)': $_"
                }
            }
        }
    }

    ################################################################################
    #####   2) Decommission the AS2GoRootCA                                   #####
    ################################################################################

    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Fully uninstall the Certification Authority '$CAName' and the Web Enrollment role on '$RootDC'."; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&No"; Help = "Skip decommissioning the Certification Authority."; Value = $Script:No }
    )
    $answer = Show-DecisionPrompt -Message "Decommission the AS2Go Certification Authority on '$RootDC'?" -Options $Options -Default 1

    if ($answer -ne $Script:Yes) {
        Write-AS2GoOutput -Type Info -Message "Skipped decommissioning the Certification Authority."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $ConfigNC = (Get-ADRootDSE -Server $RootDC).ConfigurationNamingContext

    $CAObjectsToRemove = @(
        "CN=$CAName,CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigNC"
        "CN=$CAName,CN=AIA,CN=Public Key Services,CN=Services,$ConfigNC"
        "CN=$CAName,CN=Certification Authorities,CN=Public Key Services,CN=Services,$ConfigNC"
    )

    foreach ($ObjectDN in $CAObjectsToRemove) {
        try {
            Remove-ADObject -Identity $ObjectDN -Server $RootDC -Recursive -Confirm:$false -ErrorAction Stop
            Write-AS2GoOutput -Type Success -Message "Removed AD CS object '$(Convert-FromDNToCN -DistinguishedName $ObjectDN)'." -NoExtraLines
        }
        catch {
            Write-AS2GoOutput -Type Info -Message "AD CS object '$(Convert-FromDNToCN -DistinguishedName $ObjectDN)' was not found; skipping."
        }
    }

    # CDP entries are stored one level deeper, under a container named after the CA server's short hostname.
    try {
        $ShortHostName = ($RootDC -split '\.')[0]
        $CdpDN = "CN=$ShortHostName,CN=CDP,CN=Public Key Services,CN=Services,$ConfigNC"
        Remove-ADObject -Identity $CdpDN -Server $RootDC -Recursive -Confirm:$false -ErrorAction Stop
        Write-AS2GoOutput -Type Success -Message "Removed CDP container '$ShortHostName'." -NoExtraLines
    }
    catch {
        Write-AS2GoOutput -Type Info -Message "CDP container for '$RootDC' was not found; skipping."
    }

    Write-AS2GoOutput -Type Warning -Message "NTAuthCertificates was NOT modified. If the AS2GoRootCA certificate was published there, remove it manually (verify the exact certificate first to avoid affecting other CAs)."

    try {
        Invoke-Command -ComputerName $RootDC -ErrorAction Stop -ScriptBlock {
            Uninstall-WindowsFeature ADCS-Cert-Authority, ADCS-Web-Enrollment -IncludeManagementTools
        }
        Write-AS2GoOutput -Type Success -Message "Uninstalled the Certification Authority and Web Enrollment Windows features on '$RootDC'."
    }
    catch {
        Write-AS2GoOutput -Type Warning -Message "Failed to uninstall the AD CS Windows features on '$RootDC': $_"
    }

    $Script:ADCSEnterpriseCAMissing = $true
    $Script:ADCSEnrollmentServiceMissing = $true
    $Script:ADCSASGoCTemplatesMissing = $true

    Measure-FunctionRuntime -End -Details $Info
}
