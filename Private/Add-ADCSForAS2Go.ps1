<#
.SYNOPSIS
Installs missing AD CS services on the selected domain controller.

.DESCRIPTION
Checks the selected domain controller for CA and Web Enrollment roles, installs missing services,
and reports the resulting service status.

.COMPONENT
Category: Sub Function

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

    $Info = Measure-FunctionRuntime -Begin

    $TargetServer = $Script:BestDCs[(Get-ADForest).RootDomain]
    Write-AS2GoOutput -Type TextMaker -Message "Installation will be performed on server" -TM $TargetServer 
    
    If ($Script:ADCSEnterpriseCAMissing) {
        Install-ADCSCertificateAuthority -Server $TargetServer
    }
    else {
        Write-AS2GoOutput -Type Quit -Message "The Certification Authority is already installed."
    }
    
    if ($Script:ADCSEnrollmentServiceMissing) {
        Install-ADCSEnrollmentServices -Server $TargetServer
    }
    else {
        Write-AS2GoOutput -Type Quit -Message "The Web Enrollment Service is already installed"
    }


    Invoke-Command -ComputerName $TargetServer -ScriptBlock {
        Get-Service CertSvc, W3SVC | out-host
    }



    Measure-FunctionRuntime -End -Details $Info
}