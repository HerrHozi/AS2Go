function Add-RandomUsersToAccountOperators {

    ################################################################################
    #####                                                                      ##### 
    #####    Add Random Users To Account Operators and Reset Password          #####                            
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(Mandatory)]
        [string] $TargetOU,
        [Parameter(Mandatory)]
        [string] $Server
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    #Import-Module ActiveDirectory

    [int]$UserCount = Get-ASConfig -Setting "RandomAccountOperators"
    $PasswordPlain = "!AS2Go-2026-is-Very-cool!"

    Set-ASConfig -Setting "LastPW" -Value "!AS2Go-2026-is-Very-cool!"

    # --- Resolve Account Operators (RID 548) ---
    $AOGroupSID = "S-1-5-32-548"
    $AOGroup = Get-ADGroup -Identity $AOGroupSID -Server $Server

    Write-Log -Message "    >> Target group resolved: $($ADGroup.Name) ($AOGroupSID)"

    # --- Select random users from OU ---
    $Users = Get-ADUser `
        -SearchBase $TargetOU `
        -SearchScope Subtree `
        -Filter * `
        -Properties SamAccountName -Server $Server | Get-Random -Count $UserCount

    $SecurePassword = ConvertTo-SecureString -AsPlainText -Force $PasswordPlain
    
    foreach ($User in $Users) {

        # Reset password
        Set-ADAccountPassword `
            -Identity $User.SamAccountName `
            -Reset `
            -NewPassword $SecurePassword -Server $Server

        # Ensure account is enabled
        Enable-ADAccount -Identity $User.SamAccountName -Server $Server

        # Add to Account Operators
        Add-ADGroupMember `
            -Identity $AOGroup `
            -Members $User.SamAccountName -Server $Server

        $cname = Convert-FromDNToCN -DistinguishedName $User.DistinguishedName 

        Write-Log -Message "    >> User added to Account Operators $cname"
    }
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
