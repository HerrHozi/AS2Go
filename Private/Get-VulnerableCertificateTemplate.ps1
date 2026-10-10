function Get-VulnerableCertificateTemplate {

    ################################################################################
    #####                                                                      ##### 
    #####           Finding an Vulnerable Certificate Templates                #####
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    #region ####################### main code #########################
    
    $CAtemplate = Get-ASConfig -Setting "BadCA"

    Invoke-Output -Type  CodeSnippet -M "A simple LDAP query is sufficient:"
    #$code = "`$SearchFilter =  (&(objectClass=pKICertificateTemplate)(cn=`$PublishedTemplate)(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"
    # Write-HighlightedCode  -code $code

    Write-Highlight -Text ('     $SearchFilter ', '= ', ' "(&(objectClass=pKICertificateTemplate)(cn=', '$PublishedTemplate', ')(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"')`
        -Color $fgcR, $fgcF, $fgcV, $fgcR, $fgcV, $fgcF

    Write-Highlight -Text ('     $Template     ', '= ', ' Get-ADObject ', '-SearchBase ', '"CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,', '$forest" ', '-LDAPFilter ', '$SearchFilter ', '-SearchScope ', 'OneLevel')`
        -Color $fgcR, $fgcF, $fgcC, $fgcS, $fgcV, $fgcR, $fgcS, $fgcR, $fgcS, $fgcF
    
    Write-Host ""
    Write-log -Message "     Only a simple LDAP Query is needed."
    
    $question = "Would you like to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $Script:Yes

    If ($answer -eq $Script:Yes) {
        #find vulnerable CA templates

        Foreach ($RiskyTemplate in $Script:RiskyPublishedTemplates) {
            Write-host "`n`nIdentified vulnerable certificate template " -NoNewline
            Write-host "$($RiskyTemplate.Name)" -ForegroundColor Yellow
            Write-host "on Certification Authority '$($RiskyTemplate.EnrollmentCA)'."
            Write-Host "The template can be enrolled by:`n"
   

            $DSobject = [adsi]("LDAP://$($RiskyTemplate.DN)")
            $secd = $DSobject.psbase.get_objectSecurity().getAccessRules($true, $chkInheritedPerm.checked, [System.Security.Principal.NTAccount])
            $results = $secd | Where-Object { $_.AccessControlType -eq "Allow" -and $_.ObjectType -eq "0e10c968-78fb-11d2-90d4-00c04f79dc55" -and $_.ActiveDirectoryRights -like "*ExtendedRight*" } | Select-Object IdentityReference

            foreach ($result in $results) {
                [string]$t = $result.IdentityReference
                try {
                    $sid = $result.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
                }
                catch {
                    $sid = "n/a"
                }
                [string]$displayText = "$($result.IdentityReference)"

                If ($sid -match '(-513|S-1-1-0|S-1-5-11)$') {
                    write-host ("   - $displayText").PadRight(60, [Char]32) -NoNewline
                    Write-Host " << Bingo!" -ForegroundColor Red
                    $CAtemplate = $RiskyTemplate.Name
                    $CAEnrollment = $RiskyTemplate.EnrollmentCA

                }
                elseif ($sid -match '(-515)$' ) {
                    write-host ("   - $displayText").PadRight(60, [Char]32)  -NoNewline
                    Write-Host " << Bingo!" -ForegroundColor Red
                    [string]$temp = ($temp + ' - ' + $($RiskyTemplate.Name).ToUpper())
                }
                else {
                    write-host "   - $displayText"
                }
            }
        }
    }


    Do {
        $question = "Do you want to use CA template '$CAtemplate' - Y or N? Default "
        $prompt = Get-Answer -question $question -defaultValue $Script:Yes

        if ($prompt -ne $Script:Yes) {
            write-host ""
            [int]$i = 0
            Foreach ($ca in $Script:RiskyPublishedTemplates) {
                Write-host "   [" -NoNewline
                Write-Host $i -ForegroundColor Yellow -NoNewline
                Write-host "] - $($ca.name)"
                $i++
            }
            write-host ""
            $max = $i - 1
            $i = Get-Random -Minimum 0 -Maximum $max
            [int]$selectedIndex = 0
            do { 

                $n = Read-Host "Type in the NUMBER for your preferred CA Template, e.g. $i"
                if ([int]::TryParse($n, [ref]$selectedIndex) -and $selectedIndex -ge 0 -and $selectedIndex -le $max) {
                    $repeat = $Script:No
                }
                else {
                    $repeat = $Script:Yes
                    Write-Host $n -NoNewline -ForegroundColor Yellow
                    Write-Host " is out of scope!"
                }
            } Until ($repeat -eq $Script:No)
            
            $CAtemplate = $Script:RiskyPublishedTemplates.name[$selectedIndex]
            $CAEnrollment = $Script:RiskyPublishedTemplates.EnrollmentCA[$selectedIndex]
   
      
            Set-ASConfig -Setting "BadCA" -Value $CAtemplate
            write-host ""
            

      
        }
    } Until ($prompt -eq $Script:Yes)
    
    #check if this Template can be enrolled by Domain Computers
    If ($temp.Contains("- $CAtemplate".ToUpper())) {
        [bool]$UseDomainComputers = $true
    }
    else {
        [bool]$UseDomainComputers = $false
    }

    $CA = [PSCustomObject]@{
        Name                  = $CAtemplate
        EnrollmentCA          = $CAEnrollment
        AlsoByDomainComputers = $UseDomainComputers

    } 


    Write-Log -Message "    >> using $CAtemplate, can be enrolled by Domain Computer - $UseDomainComputers"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $CA 
}
