function Get-ADCSEnrollmentServices {

    ################################################################################
    #####                                                                      ##### 
    #####    Get all Enrollment Services                                       #####                      
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$Server    
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $ConfigNC = (Get-ADRootDSE).ConfigurationNamingContext
    $caenrolls = Get-ADObject -LDAPFilter "(objectClass=pKIEnrollmentService)" `
        -SearchBase "CN=Public Key Services,CN=Services,$ConfigNC"  `
        -Properties Name, dNSHostName, certificateTemplates, flags   `
        -Server $Server

    Invoke-Output -Type H1 -Message "Identitfied Web Enrollment Services CAs"


    If ($null -ne $caenrolls) {
        $caenrolls | Select-Object Name, 
        dNSHostName, 
        @{N = 'Online'; E = { Test-Connection -ComputerName $_.dNSHostName -Count 1 -Quiet -ErrorAction SilentlyContinue } },
        @{N = 'HasTemplates'; E = { $_.certificateTemplates.Count -gt 0 } }, 
        @{N = 'Templates'; E = { $_.certificateTemplates.Count } } |  Format-Table
        $Script:ADCSEnrollmentServiceMissing = $false
    }
    else {
        Invoke-Output -Type Info -Message "No pKIEnrollmentService found."
    }

    
    $4logfile = $caenrolls | Select-Object Name, 
    dNSHostName, 
    @{N = 'Online'; E = { Test-Connection -ComputerName $_.dNSHostName -Count 1 -Quiet -ErrorAction SilentlyContinue } },
    @{N = 'HasTemplates'; E = { $_.certificateTemplates.Count -gt 0 } }, 
    @{N = 'Templates'; E = { $_.certificateTemplates.Count } } | Format-Table | out-string 
    Write-Log -Message "    >> Identified the following Web Enrollment Services in Forest '$ConfigNC': $4logfile"
  
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}