<#
.SYNOPSIS
Installs an Enterprise Root Certification Authority on a remote server.

.FUNCTIONALITY
Adds AD CS Certificate Authority features and configures the AS2Go root CA.
#>
function Install-ADCSCertificateAuthority {

    ################################################################################
    #####                                                                      ##### 
    #####    Certification Authority                                           #####                               
    #####                                                                      #####
    ################################################################################

    Param([string] $Server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type TextMaker -Message "Installing Windows Feature" -TM "ADCS-Cert-Authority (IncludeManagementTools)"
    
    Invoke-Command -ComputerName $Server -ScriptBlock {
        try {
            Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
    }
    
    Invoke-Output -Type TextMaker -Message "Installing Windows Role   " -TM "Certification Authority"
    
    Invoke-Command -ComputerName $Server -ScriptBlock {
        Install-AdcsCertificationAuthority `
            -CAType EnterpriseRootCA `
            -CACommonName "AS2GoRootCA" `
            -OverwriteExistingKey `
            -KeyLength 2048 `
            -HashAlgorithmName SHA256 `
            -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
            -ValidityPeriod Years `
            -ValidityPeriodUnits 10 `
            -Force
    }

    $Script:ADCSEnterpriseCAMissing = $false

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}