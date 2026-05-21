

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

   $CurrentFunction = Get-FunctionName
   Write-Log -Message "### Start Function $CurrentFunction ###"
   $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
   #################### main code | out- host #####################
   If (-not $SkipClearHost) { Clear-Host }
   Invoke-Output -Type Header -Message "Add AS2GO Demo Accounts to the Lab"

   [int]$recommendAmount = Get-ASConfig -Setting "LastNumofDemoUsers"
   $FileWithDemoUsers = Join-Path -Path $Script:ASSetup -ChildPath "AS2GO-DemoUsers.csv"

   if (Test-path $FileWithDemoUsers) {
      [int]$NoDemoUsers = Import-Csv $FileWithDemoUsers | Measure-Object | Select-Object -ExpandProperty Count
      Write-log -Message "    >> Number of demo users in file $FileWithDemoUsers`: $NoDemoUsers"
   }
   else {
      Invoke-output -Type Error -Message "Cannot find file '$FileWithDemoUsers' because it does not exist."
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
      $OrganizationalUnit = Select-ADObject -Title "Select Target OU - Domain switching is NOT supported (YET)!" -LocalDomainOnly
      $cname = Convert-FromDNToCN -DistinguishedName $OrganizationalUnit
      Invoke-Output -Type TextMaker -Message "Changed target OU to:" -TM $cname
   }

   Set-ASConfig -Setting "MySearchBase" -Value $OrganizationalUnit
   Set-ASConfig -Setting "PreviousBase" -Value $OrganizationalUnit

   New-DemoAccount -TargetOU $OrganizationalUnit -path $FileWithDemoUsers -NumberOfUsers $recommendAmount -UPNSuffix $UPNSuffix -Scenario $Scenario -Server $Script:LogonServer
   Add-RandomUsersToAccountOperators -TargetOU $OrganizationalUnit -Server $Script:LogonServer

   Invoke-Output -Type TextMaker -Message "Done - New Users available under" -TM $cname

   ######################## main code ############################
   $runtime = Get-RunTime -StartRunTime $StartRunTime
   Write-Log -Message "    Run Time: $runtime [h] ###"
   Write-Log -Message "### End Function $CurrentFunction ###"
}


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
      Invoke-Output -type Warning -Message "Invalid input. Only numbers between 1 and $Prompt are allowed."
   }
}