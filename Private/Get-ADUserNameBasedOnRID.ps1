function Get-ADUserNameBasedOnRID {

    ################################################################################
    #####                                                                      ##### 
    #####    Get User name based on RID independent from the OS language      #####                              
    #####                                                                      #####
    ################################################################################


    Param(
        [string] $RID,
        [string] $Server
        )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    $UserName = $null
    $UserName = (Get-ADUser -Filter * -Properties name -Server $Server | Where-Object { ($_.SID -like "*$RID") }).name
    
    If ($null -eq $UserName) {

        switch ($RID) {
            "-500" { $UserName = "Adminstrator"; Break }
            "-518" { $UserName = "Schema Admins"; Break }
            "-519" { $UserName = "Enterprise Admins"; Break }
            "-520" { $UserName = "Group Policy Creator Owners"; Break }
            "-525" { $UserName = "Protected Users"; Break }
            Default { "Nomatches" }
        }

    }

    Write-Log -Message "    >> using AD Group - $UserName"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $UserName
}
