function Get-RiskyEnrolledTemplates {

    ################################################################################
    #####                                                                      ##### 
    #####    Get all the risky & enrolled Certificate Templates                #####                               
    #####                                                                      #####
    ################################################################################

    Param([switch] $SuppressOutPut)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    $PublishedPKITemplates = New-Object System.Collections.ArrayList
    $PublishedRiskyDN = New-Object System.Collections.ArrayList
    $Script:RiskyPublishedTemplates = New-Object System.Collections.ArrayList

    try{
        $temp = Get-ADForest | Select-Object Name
        $forest = "DC=" + $temp.Name.Replace(".", ",DC=")
        $pKIEnrollmentService = Get-ADObject -SearchBase "CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,$forest" -LDAPFilter "(objectClass=pKIEnrollmentService)" -Properties * -ErrorAction Stop
    }
    catch{
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }

    foreach ($PkiEnrollment in $pKIEnrollmentService) {
    
        for ($i = 0; $i -lt $PkiEnrollment.certificatetemplates.count; $i++) {


            $items = @{
                TemplateName    = $PkiEnrollment.certificatetemplates[$i]
                CAName          = $PkiEnrollment.Name
                DNSHostName     = $PkiEnrollment.DNShostname
            }
       
            $PublishedPKITemplates.add((New-Object psobject -Property $items)) | Out-Null
        }
    }


    if ($PublishedPKITemplates) {
        # For each template name search for the object
        Foreach ($result in $PublishedPKITemplates) {
            $PublishedTemplate = $result.TemplateName
            $SearchFilter = "(&(objectClass=pKICertificateTemplate)(cn=$PublishedTemplate)(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"
            $RiskyTemplate = Get-ADObject -SearchBase "CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$forest" -LDAPFilter $SearchFilter -SearchScope OneLevel
            if ($RiskyTemplate) {
                [VOID]$PublishedRiskyDN.Add($RiskyTemplate)

                if ($SuppressOutPut -eq $true) {
                    $items = @{
                        Name           = $RiskyTemplate.Name
                        DN             = $RiskyTemplate.DistinguishedName
                        ObjectGUID     = $RiskyTemplate.ObjectGUID
                        objectClass    = $RiskyTemplate.ObjectClass
                        EnrollmentCA   = $result.DNSHostName + "\" + $result.CAName  
                        CanPublishedBy = "n/a"
                    }
                    $Script:RiskyPublishedTemplates.add((New-Object psobject -Property $items)) | Out-Null
                }
            }
        }
    }

    if ($SuppressOutPut -ne $true) {
        Write-Host "Found $($PublishedRiskyDN.count) risky AND enrolled CA templates:" -ForegroundColor Yellow
        $PublishedRiskyDN | Format-Table Name, ObjectGUID, DistinguishedName | Out-Host
    }

    $4logfile = $PublishedRiskyDN.GetEnumerator() | Format-Table -AutoSize | Out-String
    Write-Log -Message "    >> Identified the following risky published CA Templates: $4logfile"  
    $result = $PublishedRiskyDN | Select-Object Name | Select-Object -First 1

    Write-Log -Message "    >> using $($result.name)"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result.name
}
