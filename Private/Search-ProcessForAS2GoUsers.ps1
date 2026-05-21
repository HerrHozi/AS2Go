function Search-ProcessForAS2GoUsers {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $user)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################
    
    [bool]$foundUser = $false

    $result = Get-Process -IncludeUserName |  Where-Object { $_.UserName -like "*$user" }  | Select-Object Id, Name, Username, Path
    If ($result) { $foundUser = $true }

    Write-Log -Message "    >> found $user - $foundUser!"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $foundUser
}
