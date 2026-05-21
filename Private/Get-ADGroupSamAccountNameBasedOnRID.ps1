function Get-ADGroupSamAccountNameBasedOnRID {

    ################################################################################
    #####                                                                      ##### 
    #####    Get Group name based on RID independent from the OS language      #####                              
    #####                                                                      #####
    ################################################################################


    Param([string] $RID, [string] $Domain = $null)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    $GroupName = $null
    If ($null -ne $Domain) {
        $GroupName = (Get-ADGroup -Server $Domain -Filter * -Properties name | Where-Object { ($_.SID -like "*$RID") }).SamAccountName
    }
    else {
        $GroupName = (Get-ADGroup -Filter * -Properties name | Where-Object { ($_.SID -like "*$RID") }).SamAccountName
    }
    
    If ($null -eq $GroupName) {

        switch ($RID) {
            "-512" { $GroupName = "Domain Admins"; Break }
            "-518" { $GroupName = "Schema Admins"; Break }
            "-519" { $GroupName = "Enterprise Admins"; Break }
            "-520" { $GroupName = "Group Policy Creator Owners"; Break }
            "-525" { $GroupName = "Protected Users"; Break }
            "-548" { $GroupName = "Account Operators"; Break }
            Default { "Nomatches" }
        }
    }

    Write-Log -Message "    >> Identified AD Group - $GroupName for RID $RID"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $GroupName
}
