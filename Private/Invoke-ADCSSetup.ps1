<#
.COMPONENT
Category: Main Function

.SYNOPSIS
Configures Active Directory Certificate Services for the AS2Go training lab.

.DESCRIPTION
Installs AD CS and publishes AS2Go certificate templates for hands-on security training.

.FUNCTIONALITY
Selects a domain controller and inventories CAs, Enrollment Services, and template status. 
Installs missing AD CS services or creates and publishes vulnerable ESC templates and CA settings. 

.PARAMETER CTPreFix
Prefix used to identify the AS2Go certificate templates.

.EXAMPLE
Invoke-ADCSSetup -CTPreFix "AS2Go"
Configures AD CS using the AS2Go certificate-template prefix.
#>
function Invoke-ADCSSetup {

    ################################################################################
    #####                                                                      ##### 
    #####    Parent Function to setup ADCS and enroll malicious CA Templates   #####
    #####                                                                      #####
    ################################################################################

    Param([string] $CTPreFix)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type Header -Message "Setup Active Directory Certificate Services (ADCS) for AS2Go"
    
    
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Invoke-Output -Type H1 -Message ($Functionality + "`n")
    
    
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
            Invoke-Output -Type Success "ADCS setup completed successfully."
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
                        Invoke-Output -Type Warning -Message "Input is required. Empty, whitespace-only or null values are not allowed."
                    }
                } until (-not [string]::IsNullOrWhiteSpace($result))

                $CTPreFix = $result.Trim()
                Invoke-Output -Type TextMaker -Message "New template prefix:" -Tm $CTPreFix
            }
            else {
                Invoke-Output -Type Info -message "Keep default prefix ($CTPreFix) for Certificate Templates!"
            } 


            Get-ADCSCertifcateTemplates -CTPrefix $CTPreFix -Server $TargetServer
            
            If ($Script:ADCSASGoCTemplatesMissing) {
                Invoke-Output -Type TextMaker -Message "Installation will be performed on server" -TM $TargetServer
                If ($EnableLogging) {
                    Install-ADCSGoat -TemplatePreFix "$CTPreFix " -verbose -Server $TargetServer
                }
                else {
                    Install-ADCSGoat -TemplatePreFix "$CTPreFix " -Server $TargetServer
                }
                
                Invoke-Output -Type Success "Templates with prefix $CTPreFix PUBLISHED successfully."
                Get-ADCSCertifcateTemplates -CTPrefix $CTPreFix -Server $TargetServer

            }
            else {
                Invoke-Output -Type Quit -Message "All AS2Go-specific Certificate Templates are available in the Template container already."
            }
        }
        else {
            Write-log -Message "    >> Skipping ADCS setup for AS2GO."
            $repeat = $Script:No
        }

    } Until ($repeat -eq $Script:No)

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
