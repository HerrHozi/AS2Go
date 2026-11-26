function Get-VulnerableCertificateTemplate {

    ################################################################################
    #####                                                                    #####
    #####          Identify Vulnerable Published Certificate Templates       #####
    #####                                                                    #####
    ################################################################################

    [string]$DomainComputersTemplateList = ''
    $Info = Measure-FunctionRuntime -Begin

    $CAtemplate = Get-ASConfig -Setting "BadCA"
    $CAEnrollment = $null
    $UseDomainComputers = $false

    Write-AS2GoOutput -Type Important -Note "" -Message "Just a simple LDAP query is sufficient:"

    Write-Highlight -Text (
        '     $SearchFilter ',
        '= ',
        '"(&(objectClass=pKICertificateTemplate)(cn=',
        '$PublishedTemplate',
        ')(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"'
    ) -Color $fgcR, $fgcF, $fgcV, $fgcR, $fgcV, $fgcF

    Write-Highlight -Text (
        '     $Template     ',
        '= ',
        'Get-ADObject ',
        '-SearchBase ',
        '"CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,',
        '$forest" ',
        '-LDAPFilter ',
        '$SearchFilter ',
        '-SearchScope ',
        'OneLevel'
    ) -Color $fgcR, $fgcF, $fgcC, $fgcS, $fgcV, $fgcR, $fgcS, $fgcR, $fgcS, $fgcF

    $answer = $Script:Yes #Show-DecisionPrompt

    if ($answer -eq $Script:Yes) {

        $templateResults = @()

        foreach ($RiskyTemplate in $Script:RiskyPublishedTemplates) {

            $DSobject = [ADSI]("LDAP://$($RiskyTemplate.DN)")
            $securityDescriptor = $DSobject.psbase.get_objectSecurity().getAccessRules(
                $true,
                $chkInheritedPerm.checked,
                [System.Security.Principal.NTAccount]
            )

            $enrollmentPrincipals = $securityDescriptor | Where-Object {
                $_.AccessControlType -eq 'Allow' -and
                $_.ObjectType -eq '0e10c968-78fb-11d2-90d4-00c04f79dc55' -and
                $_.ActiveDirectoryRights -like '*ExtendedRight*'
            } | Select-Object -ExpandProperty IdentityReference

            $isDomainComputerEnrollable = $false
            $isAuthenticatedUsersEnrollable = $false

            foreach ($principal in $enrollmentPrincipals) {

                try {
                    $sid = $principal.Translate([System.Security.Principal.SecurityIdentifier]).Value
                }
                catch {
                    $sid = 'n/a'
                }

                if ($sid -match '(-513|S-1-1-0|S-1-5-11)$') {
                    $isAuthenticatedUsersEnrollable = $true
                }

                if ($sid -match '(-515)$') {
                    $isDomainComputerEnrollable = $true
                }
            }

            $templateResults += [PSCustomObject]@{
                Name                         = $RiskyTemplate.Name
                EnrollmentCA                 = $RiskyTemplate.EnrollmentCA
                EnrollmentPrincipals         = ($enrollmentPrincipals -join ', ')
                AuthenticatedUsersEnrollable = $isAuthenticatedUsersEnrollable
                DomainComputersEnrollable    = $isDomainComputerEnrollable
            }

            if ($isDomainComputerEnrollable) {
                $DomainComputersTemplateList = "$DomainComputersTemplateList - $($RiskyTemplate.Name)".ToUpper()
            }
        }

        if ($templateResults.Count -eq 0) {
            write-AS2GoOutput -Type Info -Message "No vulnerable published certificate templates were identified."
            Measure-FunctionRuntime -End -Details $Info
            return $null 
        }
        else {
            write-AS2GoOutput -Type Info -Message "Vulnerable published certificate template(s) identified: $($templateResults.Count)"

            for ($i = 0; $i -lt $templateResults.Count; $i++) {

                $template = $templateResults[$i]

                Write-AS2GoOutput -Type H1 -Message "$($template.Name)" -NoExtraLines
                #Write-Host " [$($i + 1)] $($template.Name)" -ForegroundColor Yellow 
                Write-Host "     CA          : $($template.EnrollmentCA)"
                Write-Host "     Risk        : ESC1 - attacker-controlled subject/SAN"
                Write-Host "     Enrollments : $($template.EnrollmentPrincipals)"

                if ($template.AuthenticatedUsersEnrollable) {
                    Write-AS2GoOutput -Type Success -Message "Authenticated user or Domain Users can request a client-authentication certificate."
                   # Write-Host "     Impact      : Any authenticated user can request a client-authentication certificate." -ForegroundColor Red
                }

                Write-Host ""
            }
        }
    }

    $title = "Select a vulnerable certificate template to continue with:"
    $default = 0 #[array]::IndexOf($uniqueAccounts.Principal, $candidate)
    $options = New-HelpOptions -InputObject $templateResults -Label "Name" -Help "EnrollmentPrincipals" -Value "IndexOf" -AddSkip
    $index = Show-DecisionPrompt -Options $options -Default $default -Title $title #-Message $message
    
    If ($index -eq $Script:No) {
        Write-As2GoOutput -Type Info -Message "No certificate template was selected."
        return $null
    }
    else {     
        $CA = [PSCustomObject]@{
            Name                  = $templateResults[$index].Name
            EnrollmentCA          = $templateResults[$index].EnrollmentCA
            AlsoByDomainComputers = $templateResults[$index].DomainComputersEnrollable
        }

        Write-AS2GoOutput -Type TextMaker -Message "Selected certificate template:" -TextMaker "$($CA.Name)"

    }

    Measure-FunctionRuntime -End -Details $Info

    return $CA
}


