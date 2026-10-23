<#
.SYNOPSIS
Configures AD CS roles and vulnerable certificate templates for the AS2Go lab.

.DESCRIPTION
Inventories enterprise certification authorities and Web Enrollment services using a preferred root-domain DC.
Offers installation of missing CA and Web Enrollment roles or creation of AS2Go certificate templates.
The template workflow accepts a custom prefix, checks for existing templates, and invokes ADCSGoat to create
and publish vulnerable templates and adjust CA settings. The menu remains available until the user skips it.

.PARAMETER CTPreFix
Initial prefix used to find and create AS2Go certificate templates. The menu can replace it with a custom prefix.

.EXAMPLE
Invoke-ADCSSetup -CTPreFix "AS2Go"
Opens the AD CS setup menu with AS2Go as the initial certificate-template prefix.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires initialized AS2Go controller mappings and the ADCSGoat tools for template creation.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Reviews certification authorities and enrollment services, then offers installation of missing AD CS roles.
Creates and publishes vulnerable certificate templates with a selected prefix and adjusts CA settings.
#>
function Invoke-ADCSSetup {

    ################################################################################
    #####                                                                      ##### 
    #####    Parent Function to setup ADCS and enroll malicious CA Templates   #####
    #####                                                                      #####
    ################################################################################

    Param([string] $CTPreFix)

    $Info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $Info.FunctionName
    
    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Setup Active Directory Certificate Services (ADCS) for AS2Go"
    
    
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message ($Functionality + "`n")
    
    
    $bestDC = Get-BestDomainController -Domain (Get-ADForest).RootDomain
    Get-ADCSEnterpriseCA -Server $bestDC
    Get-ADCSEnrollmentServices -Server $bestDC

    do {

        #Get-ADCSComponents

        $Options = @(
            [pscustomobject] @{ Label = "Install AD&CS"; Help = "Install one Certification Authority & Web Enrollment services."; Value = "ADCS" },
            [pscustomobject] @{ Label = "Add (and publish) Certificate &Templates"; Help = "Create and publish vulnerable certificate templates, e.g. ESC1"; Value = "Templates" },
            [pscustomobject] @{ Label = "&Skip"; Help = "Skip configuring ADCS for AS2GO."; Value = $Script:Skip }
        )

        $title = "AS2Go - Configure ADCS for AS2GO"
        $message = "Select an option to configure ADCS for AS2GO."
        $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 1 -Title $title

        If ($answer -eq 'ADCS') {
            Add-ADCSForAS2Go
            Write-AS2GoOutput -Type Success "ADCS setup completed successfully."
        }
        elseif ($answer -eq 'Templates') {
            
            $TargetServer = $Script:BestDCs[(Get-ADForest).RootDomain]


            $Title = "Certificate Templates - Define Prefix for misconfigured Templates"

            $Options = @(
                [pscustomobject] @{ Label = "&Use default prefix ($CTPreFix)"; Help = "Use the default prefix for certificate templates." ; Value = "Previous" },
                [pscustomobject] @{ Label = "&Define new prefix"; Help = "Define a dedicated prefix for certificate templates."; Value = "New" }
            )
            $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

            If ($Decision -eq "New") {
                do {
                    $result = Read-Host "Enter new template prefix"
                    if ([string]::IsNullOrWhiteSpace($result)) {
                        Write-AS2GoOutput -Type Warning -Message "Input is required. Empty, whitespace-only or null values are not allowed."
                    }
                } until (-not [string]::IsNullOrWhiteSpace($result))

                $CTPreFix = $result.Trim()
                Write-AS2GoOutput -Type TextMaker -Message "New template prefix:" -Tm $CTPreFix
            }
            else {
                Write-AS2GoOutput -Type Info -message "Keep default prefix ($CTPreFix) for Certificate Templates!"
            } 


            Get-ADCSCertifcateTemplates -CTPrefix $CTPreFix -Server $TargetServer
            
            If ($Script:ADCSASGoCTemplatesMissing) {
                Write-AS2GoOutput -Type TextMaker -Message "Installation will be performed on server" -TM $TargetServer
                If ($EnableLogging) {
                    Install-ADCSGoat -TemplatePreFix "$CTPreFix " -verbose -Server $TargetServer
                }
                else {
                    Install-ADCSGoat -TemplatePreFix "$CTPreFix " -Server $TargetServer
                }
                
                Write-AS2GoOutput -Type Success "Templates with prefix $CTPreFix PUBLISHED successfully."
                Get-ADCSCertifcateTemplates -CTPrefix $CTPreFix -Server $TargetServer

            }
            else {
                Write-AS2GoOutput -Type Quit -Message "All AS2Go-specific Certificate Templates are available in the Template container already."
            }
        }
        else {
            Write-log -Message "    >> Skipping ADCS setup for AS2GO."
            $repeat = $Script:No
        }

    } Until ($repeat -eq $Script:No)

    Measure-FunctionRuntime -End -Details $Info
}
