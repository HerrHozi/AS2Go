function Start-GroupManipulation {

    ################################################################################
    #####                                                                      ##### 
    #####    Start Process to remove all users, except the BGA & BDA           #####                                
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(Mandatory)]
        [string] $Server,
        [Parameter(Mandatory)]
        $Groups,
        [Parameter(Mandatory)] 
        [string] $BreakGlassAccount,
        [Parameter(Mandatory)]
        [string] $BackDoorAccount
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    try {

        foreach ($grp in $Groups) {

            $Server = $grp.domain
            $group = Get-ADGroup -Identity $grp.SID -Server $Server -ErrorAction Stop

            Invoke-Output -Type Info -Message "Processing Group: $($grp.CanonicalName)"
            $members = Get-ADGroupMember -Identity $group -Recursive:$false -Server $Server

            foreach ($member in $members) {

                $memberSID = $member.SID.Value

                if ($memberSID -ne $BreakGlassAccount -and $memberSID -ne $BackDoorAccount) {
                    try {
                        Invoke-Output -Type Bullet -Message "Removing " -TM "$($member.SamAccountName) [$memberSID]"
                        Remove-ADGroupMember -Identity $group `
                            -Members $member `
                            -Confirm:$false  `
                            -Server $Server -ErrorAction Stop
                    }
                    catch {
                        Invoke-Output -Type Error -Message $_
                    }
                }
                else {
                    Invoke-Output -Type H1 -Message "  + Keeping  $($member.SamAccountName) [$memberSID]"
                }
            }
        }
        Invoke-Output -Type Success -Message  "Group Manipulation Completed."
    }
    catch {
        Invoke-Output -Type Error -Message $_
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}