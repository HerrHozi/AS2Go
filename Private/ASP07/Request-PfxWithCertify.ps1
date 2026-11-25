function Request-PfxWithCertify {

    ################################################################################
    #####                                                                      ##### 
    #####                 Requesting Certificate with Certify                  #####                            
    #####                                                                      #####
    ################################################################################

    Param(
        [PSCustomObject]$Certificate, 
        [PSCustomObject]$AlternativeAccount
    )

    $Info = Measure-FunctionRuntime -Begin

    [string] $CertificationAuthority = $Certificate.EnrollmentCA
    [string] $CertificateName = $Certificate.Name
    [bool] $CanEnrolledByDomainComputers = $Certificate.AlsoByDomainComputers 

    If ($AlternativeAccount.UPN -like "*@*") {
        $altname1 = $AlternativeAccount.upn
    }
    else {
        $altname1 = $AlternativeAccount.samaccountname  
    }

    $sid = $AlternativeAccount.SID
    
    #".\Certify.exe request --ca ROOT-DC19-01.WS19-ROOT.CORP\WS19-ROOT --template CH01-BadCert --upn Administrator --sid S-1-5-21-3434748730-880471986-746661712-500"
    Write-AS2GoOutput -Type CodeSnippet -Message "Command:"

    Write-Highlight -Text "     .\certify.exe ", "request ", "--ca ", $CertificationAuthority, " --template ", $CertificateName, " --upn ", $altname1, " --sid ", $sid   `
        -Color $fgcC, $fgcF, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host ""

    #Write-Log -Message "     >> .\certify.exe request /ca:$CertificationAuthority /template:$CertificateName /altname:$altname"

    $hostname = $env:COMPUTERNAME
    If ($CanEnrolledByDomainComputers -eq $true) {

        Write-Host "`n`n  Domain Computers " -ForegroundColor Yellow -NoNewline
        Write-Host "can enroll your selected template - " -NoNewline
        Write-Host "$CertificateName" -ForegroundColor Yellow -NoNewline
        Write-Host "? Do you want to add the parameter - " -NoNewline
        Write-host "/machine`n" -ForegroundColor Yellow

        Write-AS2GoOutput -Type CodeSnippet -Message "Command:"
        Write-Highlight -Text "     .\certify.exe ", "request ", "/ca:", $CertificationAuthority, " /template:", $CertificateName, " /altname:", $altname, " /machine:", $hostname    `
            -Color $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcF, $fgcV
        
        $question = "Press - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Script:Yes

        IF ($answer = "R") {}
    }

    $question = "Would you like to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $Script:Yes

    If ($answer -eq $Script:Yes) {
        Write-AS2GoOutput -Type Codesnippet -Message "Requesting Certificate with Certify ..."

        #Check connection to Enterprise CA
        $result = certutil -config $CertificationAuthority -ping

        #Request a Certificates
        If ($result[2].ToLower().Contains("successfully") -eq $True) {

            $Script:ASTools = Get-ASConfig -Setting "Tools"
            $result = & "$($Script:ASTools)\certify.exe" request --ca $CertificationAuthority --template $CertificateName --upn $altname1 --sid $sid
            $result | Out-Host


            $PfxBase64 = [regex]::Match(
                $result,
                '(?s)\[\*\] Certificate \(PFX\)\s*:\s*(?<pfx>[A-Za-z0-9+/=\r\n]+?)\s*Certify completed'
            ).Groups['pfx'].Value -replace '\s+', ''

            #$PfxBase64  | Out-Host


        }
        else {
            Write-Host $result[1] -ForegroundColor red
            Write-Host $result[3]
            Write-Host $result[4]
            return $null
        }
        
    }
    else {
        return $null
    }
 

    Write-AS2GoOutput -Type Success -Message "Certificate Requesting with Certify was successful! The certificate is stored in variable `$PfxBase64."

    If (-not $unAttended) {
        pause
    }


    Measure-FunctionRuntime -End -Details $Info

    return $PfxBase64
}
