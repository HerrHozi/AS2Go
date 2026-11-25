function Remove-AS2GoGroupMembers {

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

    $Info = Measure-FunctionRuntime -Begin

    try {

        foreach ($grp in $Groups) {

            $Server = $grp.domain
            $group = Get-ADGroup -Identity $grp.SID -Server $Server -ErrorAction Stop

            Write-AS2GoOutput -Type Info -Message "Processing Group: $($grp.CanonicalName)"
            $members = Get-ADGroupMember -Identity $group -Recursive:$false -Server $Server

            foreach ($member in $members) {

                $memberSID = $member.SID.Value

                if ($memberSID -ne $BreakGlassAccount -and $memberSID -ne $BackDoorAccount) {
                    try {
                        Write-AS2GoOutput -Type Bullet -Message "Removing " -TM "$($member.SamAccountName) [$memberSID]"
                        Remove-ADGroupMember -Identity $group `
                            -Members $member `
                            -Confirm:$false  `
                            -Server $Server -ErrorAction Stop
                    }
                    catch {
                        Write-AS2GoOutput -Type Error -Message $_
                    }
                }
                else {
                    Write-AS2GoOutput -Type H1 -Message "  + Keeping  $($member.SamAccountName) [$memberSID]"
                }
            }
        }
        Write-AS2GoOutput -Type Success -Message  "Group Manipulation Completed."
    }
    catch {
        Write-AS2GoOutput -Type Error -Message $_
    }

    Measure-FunctionRuntime -End -Details $Info
}