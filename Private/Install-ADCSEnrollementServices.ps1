<#
.SYNOPSIS
Installs the AD CS Web Enrollment role on a remote server.

.FUNCTIONALITY
Adds the Web Enrollment feature and configures the AD CS enrollment website.
#>
function Install-ADCSEnrollmentServices {

    ################################################################################
    #####                                                                      ##### 
    #####    Certification Authority Web Enrollment                            #####                               
    #####                                                                      #####
    ################################################################################

    Param([string] $Server)

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type TextMaker -Message "Installing Windows Feature" -TM "ADCS-Web-Enrollment (IncludeManagementTools)"
    
    Invoke-Command -ComputerName $Server -ScriptBlock {
        try {
            Install-WindowsFeature ADCS-Web-Enrollment -IncludeManagementTools
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
    }
    
    Write-AS2GoOutput -Type TextMaker -Message "Installing Windows Role   " -TM "Certification Authority Web Enrollment"
    
    Invoke-Command -ComputerName $Server -ScriptBlock {
        Install-AdcsWebEnrollment -Force
    }

    $Script:ADCSEnrollmentServiceMissing = $false

    Measure-FunctionRuntime -End -Details $Info
}