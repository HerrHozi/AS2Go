<#
.SYNOPSIS
Adds randomly selected demo users to Account Operators.

.DESCRIPTION
Selects demo users at random, enables their accounts, resets lab passwords, and adds them to
the Account Operators group.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Selects random users, enables them, resets lab passwords, and adds them to Account Operators.
#>
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

    $Info = Measure-FunctionRuntime -Begin

    #Import-Module ActiveDirectory

    [int]$UserCount = Get-ASConfig -Setting "RandomAccountOperators"
    $PasswordPlain = Get-ASConfig -Setting "LastPW"

    #Set-ASConfig -Setting "LastPW" -Value $PasswordPlain

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
    Measure-FunctionRuntime -End -Details $Info
}
