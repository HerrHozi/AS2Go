function Search-ProcessForAS2GoUsers {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $user)

    $Info = Measure-FunctionRuntime -Begin
    
    [bool]$foundUser = $false

    $result = Get-Process -IncludeUserName |  Where-Object { $_.UserName -like "*$user" }  | Select-Object Id, Name, Username, Path
    If ($result) { $foundUser = $true }

    Write-Log -Message "    >> found $user - $foundUser!"
    Measure-FunctionRuntime -End -Details $Info

    return $foundUser
}
