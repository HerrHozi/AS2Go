<#
.SYNOPSIS
Prepares DNS and honeytoken settings for Defender for Identity demonstrations.

.DESCRIPTION
Displays a repeatable setup menu for DNS zone-transfer settings and honeytoken account selection.
The DNS workflow reviews primary zones, previews changes, and can allow transfers to any server after confirmation.
The honeytoken workflow selects an existing AD user and saves its distinguished name in the module configuration.
Skips DNS setup when the DNS module status is failed. Selecting Skip exits the menu.

.EXAMPLE
Invoke-MDITriggers
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Does not configure Defender for Identity itself or register the selected user as a honeytoken in that service.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Offers DNS zone-transfer setup and selection of an existing honeytoken account for later detection demonstrations.
Can allow transfers to any server and stores the selected honeytoken in the AS2Go configuration.
#>
function Invoke-MDITriggers {

    $Info = Measure-FunctionRuntime -Begin

    ################################################################################
    #####                                                                      ##### 
    #####    Configure AD Enviroment for MDI  specific detections              #####                              
    #####                                                                      #####
    ################################################################################


    Write-AS2GoOutput -Type Header "Configure settings to enable MDI specific detections"
    $Functionality = (Get-Help 'Invoke-MDITriggers').Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality
    
    $title = "MDI Triggers"
    $message = "Follow listed order for optimal execution."

    $Options = @(
        [pscustomobject] @{ Label = "DNS &Zone"; Help = "Update the DNS setting 'Zone Transfer' to 'TransferAnyServer'. Required only when Microsoft Defender for Identity is installed."; Value = "DNSZone" },
        [pscustomobject] @{ Label = "Select &HoneyToken"; Help = "Select a honeytoken account that will be monitored by Microsoft Defender for Identity."; Value = "HoneyToken" },     
        [pscustomobject] @{ Label = "&Skip"; Help = "Skip the MDI specific detections."; Value = $Script:Skip }
    )

    $repeat = $Script:Yes
    do {

 
        $decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
        
        switch ($decision) {

            "DNSZone" {
                If ($Script:MoDNS -ne "failed") {
                    Set-AS2GoDnsZoneConfiguration
                }
                else {
                    Write-AS2GoOutput -Type Warning -Message "DNSServer PowerShell module is not available. Cannot proceed with DNS Zone Update."
                }
            }
            "HoneyToken" {
                Set-Honeytoken
            }
            $Script:Skip {
                Write-Log -Message "Skipped MDI specific detections!"
                $repeat = $Script:No
            }


        }
    } Until ($repeat -eq $Script:No)

    Write-Log -Message "    >> using "
    Measure-FunctionRuntime -End -Details $Info

    #return $true
}