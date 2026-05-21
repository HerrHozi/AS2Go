function Invoke-GroupManipulation {

    ################################################################################
    #####                                                                      ##### 
    #####   Identity all priviledge groups in the AD based on your searchbase  #####                              
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

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

    Invoke-Output -Type Header -Message "Identified privileged groups"
   
    If ($groups) {

        $groups | Select-Object SamAccountName, CanonicalName, Domain, SID | Sort-Object CanonicalName  | out-host

    }
    else {
        $cname = Convert-FromDNtoCN -DistinguishedName $TargetDN
        Invoke-Output -Type Warning -Message "No previledge groups identified under $cname"
        return
    }
       
    Invoke-Output -Type Info -Message "The specified Break Glass Account and Back Door Account will be ignored"
    Invoke-Output -Type Bullet -Message "Backdoor Account:   " -TM $BDAccount.cn
    Invoke-Output -Type Bullet -Message "Break Glass Account:" -TM $BGAccount.cn
    
    $title = "The identified privileged groups will now be purged. `nAll existing memberships will be permanently removed within the selected scope." 
    $Message = "Proceed with execution?"
 
    $answer = Show-DecisionPrompt -Title $title -Message $message
    If ($answer -eq $Script:Yes) {
        Start-GroupManipulation -Server $Script:ASDC -Groups $groups -BreakGlassAccount $BGA -BackDoorAccount $BDA
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}