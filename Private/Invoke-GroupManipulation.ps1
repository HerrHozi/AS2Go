<#
.SYNOPSIS
Removes direct members from privileged groups in a selected AD scope.

.DESCRIPTION
Prompts for a target scope and reads the configured privileged group RIDs to identify matching groups.
Resolves the configured break-glass and last backdoor account SIDs and displays the affected groups.
After confirmation, invokes Remove-AS2GoGroupMembers to remove direct memberships except those protected SIDs.
If configured accounts are absent, the implementation retains its fallback SID values; it does not create accounts.

.EXAMPLE
Invoke-GroupManipulation
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires initialized AS2Go settings and permission to change the selected group memberships.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Selects an AD scope and finds privileged groups using the configured group RIDs.
After confirmation, removes direct members while retaining the protected break-glass and backdoor account SIDs.
#>
function Invoke-GroupManipulation {

    ################################################################################
    #####                                                                      ##### 
    #####   Identity all priviledge groups in the AD based on your searchbase  #####                              
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    $BGA = "S-1-5-21-18515944-1610616278-1029250612-500"
    $BDA = "S-1-5-21-18515944-1610616278-1029250612-500"

    $targetDN = New-TargetBase

    $LastBDUserDN = Get-ASConfig -Setting "LastBDUser"
    $BreakGlassAccountDN = Get-ASConfig -Setting "BreakGlassAccount"
  
    if ($BreakGlassAccountDN) {
        $BGAccount = Get-ADUserDetails -SearchByDN -Identifier $BreakGlassAccountDN
        $BGA = $BGAccount.SID
    }
    else {
        Set-BreakGlassAccount
        Write-Log -Message "No Break Glass Account specified in configuration. Please set the value for 'BreakGlassAccount' in the configuration file." -Type Warning
    }

    if ($LastBDUserDN) {
        $BDAccount = Get-ADUserDetails -SearchByDN -Identifier $LastBDUserDN
        $BDA = $BDAccount.SID
    }
    else {
        Write-Log -Message "No Back Door Account specified in configuration. Please set the value for 'LastBDUser' in the configuration file."
    }





    $rids = Get-ASConfig -Setting "PriviledgeGroupRIDs"
    $grouprids = $rids -split ',' | ForEach-Object {
        $_.Trim(" '")
    }

    If ($targetDN -match 'OU=|CN=|DC=' ) {

        $result = Convert-FromDNToCN -DistinguishedName $targetDN
        $fqdn = $result.Split('/')[0]
        $Script:ASDC = Get-BestDomainController -domain $fqdn
        $groups = Get-ADGroup -Filter * -Properties CanonicalName, SID, SamAccountName, name `
            -Server $Script:ASDC  `
            -SearchBase $TargetDN `
            -SearchScope Subtree  | 
        Where-Object {
            ($_.SID.Value -split '-')[-1] -in $grouprids
        } |
        Select-Object CanonicalName, SID, SamAccountName, name, @{N = 'Domain'; E = { $_.CanonicalName.Split("/")[0] } } 
    }
    else {
        ForEach ($SeachBase in $targetDN) {
            Write-Host $SeachBase

            $groups += Get-ADGroup -Filter * -Properties CanonicalName, SID, SamAccountName, name `
                -Server $SeachBase  `
                -SearchScope Subtree  | 
            Where-Object {
                ($_.SID.Value -split '-')[-1] -in $grouprids
            } |
            Select-Object CanonicalName, SID, SamAccountName, name, @{N = 'Domain'; E = { $_.CanonicalName.Split("/")[0] } } 

        }
    }

    Write-AS2GoOutput -Type Header -Message "Identified privileged groups"
   
    If ($groups) {

        $groups | Select-Object SamAccountName, CanonicalName, Domain, SID | Sort-Object CanonicalName  | out-host

    }
    else {
        $cname = Convert-FromDNtoCN -DistinguishedName $TargetDN
        Write-AS2GoOutput -Type Warning -Message "No previledge groups identified under $cname"
        return
    }
       
    Write-AS2GoOutput -Type Info -Message "The specified Break Glass Account and Back Door Account will be ignored"
    Write-AS2GoOutput -Type Bullet -Message "Backdoor Account:   " -TM $BDAccount.cn
    Write-AS2GoOutput -Type Bullet -Message "Break Glass Account:" -TM $BGAccount.cn
    
    $title = "The identified privileged groups will now be purged. `nAll existing memberships will be permanently removed within the selected scope." 
    $Message = "Proceed with execution?"
 
    $answer = Show-DecisionPrompt -Title $title -Message $message
    If ($answer -eq $Script:Yes) {
        Remove-AS2GoGroupMembers -Server $Script:ASDC -Groups $groups -BreakGlassAccount $BGA -BackDoorAccount $BDA
    }

    Measure-FunctionRuntime -End -Details $Info
}