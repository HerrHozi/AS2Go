function Install-ADCSEnrollmentServices {

    ################################################################################
    #####                                                                      ##### 
    #####    Certification Authority Web Enrollment                            #####                               
    #####                                                                      #####
    ################################################################################

    Param([string] $Server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type TextMaker -Message "Installing Windows Feature" -TM "ADCS-Web-Enrollment (IncludeManagementTools)"
    
    Invoke-Command -ComputerName $Server -ScriptBlock {
        try {
            Install-WindowsFeature ADCS-Web-Enrollment -IncludeManagementTools
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
    }
    
    Invoke-Output -Type TextMaker -Message "Installing Windows Role   " -TM "Certification Authority Web Enrollment"
    
    Invoke-Command -ComputerName $Server -ScriptBlock {
        Install-AdcsWebEnrollment -Force
    }

    $Script:ADCSEnrollmentServiceMissing = $false

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}