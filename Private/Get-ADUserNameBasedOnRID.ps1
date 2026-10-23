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

    $Info = Measure-FunctionRuntime -Begin

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
    Measure-FunctionRuntime -End -Details $Info

    return $UserName
}
