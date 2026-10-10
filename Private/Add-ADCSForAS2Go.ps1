<#
.SYNOPSIS
Installs missing AD CS services on the selected domain controller.

.FUNCTIONALITY
Checks CA and Web Enrollment status, installs missing roles, then reports their service state.
#>
function Add-ADCSForAS2Go {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $TargetServer = $Script:BestDCs[(Get-ADForest).RootDomain]
    Invoke-Output -Type TextMaker -Message "Installation will be performed on server" -TM $TargetServer 
    
    If ($Script:ADCSEnterpriseCAMissing) {
        Install-ADCSCertificateAuthority -Server $TargetServer
    }
    else {
        Invoke-Output -Type Quit -Message "The Certification Authority is already installed."
    }
    
    if ($Script:ADCSEnrollmentServiceMissing) {
        Install-ADCSEnrollmentServices -Server $TargetServer
    }
    else {
        Invoke-Output -Type Quit -Message "The Web Enrollment Service is already installed"
    }


    Invoke-Command -ComputerName $TargetServer -ScriptBlock {
        Get-Service CertSvc, W3SVC | out-host
    }



    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}