function Invoke-MDITriggers {

    ################################################################################
    #####                                                                      ##### 
    #####    Configure AD Enviroment for MDI  specific detections              #####                              
    #####                                                                      #####
    ################################################################################


    Invoke-Output -Type Header "Configure settings to enable MDI specific detections"
    
    $title = "MDI Triggers"
    $message = "Follow listed order for optimal execution."

    $Options = @(
        [pscustomobject] @{ Label = "DNS &Zone"; Help = "Update the DNS setting 'Zone Transfer' to 'TransferAnyServer'. Required only when Microsoft Defender for Identity is installed."; Value = "DNSZone" },
        [pscustomobject] @{ Label = "&Select HoneyToken"; Help = "Select a honeytoken account that will be monitored by Microsoft Defender for Identity."; Value = "HoneyToken" },     
        [pscustomobject] @{ Label = "&Quit"; Help = "Exit the AS2Go Active Directory setup."; Value = "Quit" }
    )

    $repeat = $Script:Yes
    do {

        $decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
        Clear-Host
        
        switch ($decision) {

            "DNSZone" {
                If ($MoDNS -ne "failed") {
                    Invoke-DNSZoneUpdate
                }
                else {
                    Invoke-Output -Type Warning -Message "DNSServer PowerShell module is not available. Cannot proceed with DNS Zone Update."
                }
            }
            "HoneyToken" {
                Set-HoneyToken
            }
            "Quit" {
                Write-Log -Message "Skipped AS2Go Lab Setup!"
                $repeat = $Script:No
            }


        }
    } Until ($repeat -eq $Script:No)

    Write-Log -Message "    >> using "
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $true
}