

<#
.SYNOPSIS
Creates AS2Go demo and victim accounts in a selected Active Directory OU.

.DESCRIPTION
Reads AS2GO-DemoUsers.csv and offers the saved account count or a custom count within the available CSV rows.
Prompts for the default Demo Accounts OU or another OU and saves the selected search base in module settings.
Creates randomly selected CSV users with scenario attributes and optional nested OUs through New-DemoAccount.
Then adds random users to Account Operators and creates a victim account, optionally joining the victim group.
Either selection step can be skipped. Directory operations use the configured logon server.

.PARAMETER AS2GoOU
Parent OU name used to build the default OU=Demo Accounts path. Defaults to AS2Go.

.PARAMETER Scenario
Scenario label passed to New-DemoAccount for account display names. Defaults to AS2Go.

.PARAMETER UPNSuffix
UPN suffix passed to the account-creation helpers. Defaults to @mrhozi.com.

.PARAMETER Server
Mandatory string accepting pipeline input. The current implementation uses Script:LogonServer for AD operations.

.EXAMPLE
Invoke-DemoAccounts -Server "DC01.example.com" -AS2GoOU "AS2Go" -UPNSuffix "@example.com"
Opens account creation with the AS2Go parent OU and the example.com UPN suffix.

.INPUTS
System.String. The Server parameter accepts pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires the demo-user CSV, initialized lab settings, and rights to create users, OUs, and group memberships.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Selects a user count and target OU, then creates demo accounts from the configured CSV data.
Adds random users to Account Operators and creates a victim account with optional victim-group membership.
#>
Function Invoke-DemoAccounts {

   ################################################################################
   ######                                                                     #####
   ######    Parent Function to create Demo Accounts                          #####
   ######                                                                     #####
   ################################################################################

   param(
      [string] $AS2GoOU = "AS2Go", 
      [string] $Scenario = "AS2Go", 
      [string] $UPNSuffix = "@mrhozi.com",
      [Parameter(ValueFromPipeline, Mandatory)]
      [string]$Server
   )

   $Info = Measure-FunctionRuntime -Begin
   
   If (-not $SkipClearHost) { Clear-Host }
   Write-AS2GoOutput -Type Header -Message "Add AS2Go Demo Accounts to the Lab"

   $Functionality = (Get-Help $CurrentFunction).Functionality
   Write-AS2GoOutput -Type H1 -Message $Functionality


   [int]$recommendAmount = Get-ASConfig -Setting "LastNumofDemoUsers"
   $FileWithDemoUsers = Join-Path -Path $Script:ASSetup -ChildPath "AS2GO-DemoUsers.csv"

   if (Test-path $FileWithDemoUsers) {
      [int]$NoDemoUsers = Import-Csv $FileWithDemoUsers | Measure-Object | Select-Object -ExpandProperty Count
      Write-log -Message "    >> Number of demo users in file $FileWithDemoUsers`: $NoDemoUsers"
   }
   else {
      Write-AS2GoOutput -Type Error -Message "Cannot find file '$FileWithDemoUsers' because it does not exist."
      return
   }

   If ($NoDemoUsers -lt $recommendAmount ) {
      Write-log -Message "    >> Recuded number of demo from $recommendAmount to $NoDemoUsers!"
      [int]$recommendAmount = $NoDemoUsers
   }

   $Options = @(
      [pscustomobject] @{ Label = "&Confirm"; Help = "Confirm the default value ($recommendAmount)."; Value = "C" },
      [pscustomobject] @{ Label = "&Other Value"; Help = "Specify a custom value (maximum: $NoDemoUsers)."; Value = "O" },
      [pscustomobject] @{ Label = "&Skip"; Help = "Skip creating demo users."; Value = "S" }
   )

   $title = "AS2Go - Specify the number of new AS2GO Demo Users"
   $message = "Press Enter to confirm the default value ($recommendAmount) or select an option below."
   $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

   If ($answer -eq 'O') {
      $recommendAmount = Read-Value -Prompt $NoDemoUsers
      Set-ASConfig -Setting "LastNumofDemoUsers" -Value $recommendAmount
   }
   elseif ($answer -eq 'S') {
      Write-log -Message "    >> Skipping creation of demo users."
      return
   }
   Write-log -Message "    >> Final number of demo users to create`: $recommendAmount"

   $OrganizationalUnit = "OU=Demo Accounts,OU=$AS2GoOU,$((Get-ADDomain).DistinguishedName)"
   $cname = Convert-FromDNToCN -DistinguishedName $OrganizationalUnit

   $Options = @(
      [pscustomobject] @{ Label = "&Confirm"; Help = "Use the default ($cname)."; Value = "C" },
      [pscustomobject] @{ Label = "&Other OU"; Help = "Select a different organizational unit."; Value = "O" },
      [pscustomobject] @{ Label = "&Skip"; Help = "Skip creating demo users."; Value = "S" }
   )

   $title = "AS2Go - Select target OU for new AS2GO demo accounts."
   $message = "Press Enter to confirm the default OU '$cname' or choose an option below."
   $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

   If ($answer -eq "O") {
      $OrganizationalUnit = Select-ADObject -Title "Select Target OU - Domain switching is NOT supported (YET)!" -LocalDomainOnly -AddOU
      if ($OrganizationalUnit -eq $null) {
         Write-AS2GoOutput -Type Warning -Message "No organizational unit was selected. Using the default OU."
         $OrganizationalUnit = "OU=Demo Accounts,OU=$AS2GoOU,$((Get-ADDomain).DistinguishedName)"
         $cname = Convert-FromDNToCN -DistinguishedName $OrganizationalUnit
      }
      else {
         $cname = Convert-FromDNToCN -DistinguishedName $OrganizationalUnit
         Write-AS2GoOutput -Type TextMaker -Message "Changed target OU to:" -TM $cname
      }

   }

   Set-ASConfig -Setting "AS2GoSearchBase" -Value $OrganizationalUnit
   Set-ASConfig -Setting "PreviousBase" -Value $OrganizationalUnit



   New-DemoAccount -TargetOU $OrganizationalUnit -path $FileWithDemoUsers -NumberOfUsers $recommendAmount -UPNSuffix $UPNSuffix -Scenario $Scenario -Server $Script:LogonServer
   Add-RandomUsersToAccountOperators -TargetOU $OrganizationalUnit -Server $Script:LogonServer

   $pw = Get-ASConfig -Setting "LastPW"
   $VISecurePass = ConvertTo-SecureString -String $pw -AsPlainText -Force
   Add-VictimAccount -TargetOU $OrganizationalUnit -UPNSuffix $UPNSuffix -Server $Script:LogonServer -AccountPassword $VISecurePass

   Write-AS2GoOutput -Type TextMaker -Message "Done - New Users available under" -TM $cname
   Measure-FunctionRuntime -End -Details $Info
}


<#
.SYNOPSIS
Prompts for a positive integer within a specified limit.

.DESCRIPTION
Repeats the prompt until the user enters an integer from 1 through the supplied maximum.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Validates entered values and returns the first number between one and the supplied maximum.
#>
function Read-Value {
   param (
      [int]$Prompt
   )

   while ($true) {
      $inputValue = Read-Host "`n  Please enter a value between 1 and $Prompt"
      if ($inputValue -match '^\d+$') {
         $number = [int]$inputValue
         if ($number -gt 0 -and $number -le $Prompt) {
            return $number
         }
      }
      Write-AS2GoOutput -type Warning -Message "Invalid input. Only numbers between 1 and $Prompt are allowed."
   }
}