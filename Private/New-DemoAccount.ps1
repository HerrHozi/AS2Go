<#
.SYNOPSIS
Creates demo Active Directory users from the configured CSV file.

.FUNCTIONALITY
Checks the OU, optionally builds nested OUs, then creates selected users with scenario data.
#>
function New-DemoAccount {

    param(
        [string]$Path,
        [string]$TargetOU,
        [string]$UPNSuffix,
        [Parameter(Mandatory)][string]$Server,
        [string]$Scenario,
        [int]$NumberOfUsers
    )

    ################################################################################
    ######                                                                     #####
    ######    Adding Demo Accounts based on FakeNameGenerator.com CSV File     #####
    ######                                                                     #####
    ################################################################################


    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
    
    if ($total -eq 0) {
        Write-Host "No users loaded." -ForegroundColor Yellow
        return
    }

    $ou = Invoke-ADOUPathCheck -DistinguishedName $TargetOU -Server $Server
    $cname = Convert-FromDNToCN -DistinguishedName $ou.DistinguishedName


    $users = Import-Csv $Path | Get-Random -Count $NumberOfUsers
    $total = $users.Count
    $UniqueCountryCodes = $users | Select-Object -ExpandProperty Country -Unique

    $Options = @(
        [pscustomobject] @{ Label = "&Confirm"; Help = "Provision demo accounts in the default OU: $cname."; Value = "Default" },
        [pscustomobject] @{ Label = "Nested by &department "; Help = "Create one additional OU level and provision accounts: $cname/<department>"; Value = "Department" },
        [pscustomobject] @{ Label = "Nested by &location "; Help = "Create one additional OU level and provision accounts: $cname/<country>"; Value = "Country" },
        [pscustomobject] @{ Label = "Nested by location &and department"; Help = "Create two additional OU levels and provision accounts: $cname/<country>/<department>"; Value = "TwoLevel" }
    )

    $title = "AS2GO - Select target OU structure for new AS2GO demo accounts"
    $message = "Press Enter to use the default structure '$cname' or choose an option below."
    $OUStructure = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

    If ($OUStructure -ne "Default") {

        Invoke-Output -Type CodeSnippet -Message "Start creating sub '$OUStructure' OUs ..."

        $i = 0

        If ($OUStructure -eq "Country") {
            $UniqueCountryCodes | ForEach-Object {
                $newOU = "OU=$_,$TargetOU"
                $ou = Invoke-ADOUPathCheck -DistinguishedName $newOU -Server $Server
                $i++
            }
        }
        elseIf ($OUStructure -eq "Department") {
            $Script:Departments.Name | ForEach-Object {
                $newOU = "OU=$_,$TargetOU"
                $ou = Invoke-ADOUPathCheck -DistinguishedName $newOU -Server $Server
                $i++
            }
        }
        elseIf ($OUStructure -eq "TwoLevel") {
            $UniqueCountryCodes | ForEach-Object {
                $newOU = "OU=$_,$TargetOU"
                $Script:Departments.Name | ForEach-Object {
                    $newOUL2 = "OU=$_,$newOU"
                    $ou = Invoke-ADOUPathCheck -DistinguishedName $newOUL2 -Server $Server
                    $i++
                }
            }
        }
        else {

        }
        Invoke-Output -Type Success -Message "Finished creating of '$i' sub level OUs."
    }

    $UPNSuffix = Set-UPNSuffix


    Invoke-Output -Type Quit -Message "Press 'Q' at any time to abort creating '$total' Demo Users!"

    $startTime = Get-Date
    
    # --- Random Department & Title ---
    $Departments = $Script:Departments

    # ---- PARALLEL JOB ----
    $job = $users | ForEach-Object -Parallel {

        try {

            $id = [int]($_.Number)
            $ComplexPW = "$($_.Password)!2xY" 
            [int]$maxD = ($using:Departments).Count
            [int]$deptIndex = Get-Random -Minimum 0 -Maximum $maxD
            $localDepartments = $using:Departments
            $CO = ($_.Country)

            $newOU = switch ($using:OUStructure) {
                "Country" { "OU=$CO,$($using:TargetOU)" }
                "Department" { "OU=$($localDepartments[$deptIndex].Name),$($using:TargetOU)" }
                "TwoLevel" { "OU=$($localDepartments[$deptIndex].Name),OU=$CO,$($using:TargetOU)" }
                default { $using:TargetOU }
            }
            
            New-ADUser `
                -Name "$($_.Surname), $($_.GivenName)" `
                -GivenName $_.GivenName `
                -Surname $_.Surname `
                -SamAccountName $_.Username `
                -UserPrincipalName ($_.Username + $using:UPNSuffix) `
                -EmailAddress ("{0}.{1}@{2}" -f $_.GivenName, $_.Surname, $using:UPNSuffix) `
                -DisplayName  "$($_.Surname), $($_.GivenName) ($($using:Scenario))" `
                -Description 'AS2Go Demo User'  `
                -StreetAddress $_.StreetAddress `
                -PostalCode $_.ZipCode `
                -City $_.City `
                -State $_.State `
                -Country $_.Country `
                -OfficePhone $_.OfficePhone `
                -employeeID ($_.Country + $id.ToString('D6')) `
                -OtherAttributes @{ 'employeeType' = 'AS2GoDemoUser'
                'telephoneNumber'                  = $_.TelephoneNumber
            } `
                -Department $localDepartments[$deptIndex].Name  `
                -Title $localDepartments[$deptIndex].Positions[(Get-Random -Minimum 0 -Maximum $localDepartments[$deptIndex].Positions.Count)]  `
                -AccountPassword (ConvertTo-SecureString $ComplexPW -AsPlainText -Force) `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -Path $newOU `
                -Server $using:Server `
                -ErrorAction SilentlyContinue

            [PSCustomObject]@{
                Success = $true
            }
        }
        catch {
            #$_.Exception.Message | Write-Host -ForegroundColor Red
            [PSCustomObject]@{
                Success = $false
            }
        }

    } -ThrottleLimit 35 -AsJob


    $processed = 0

    # ---- MONITOR LOOP ----
    while ($job.State -eq "Running") {

        if ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq 'Q') {
                Stop-Job $job
                break
            }
        }

        $resultsSoFar = Receive-Job $job -Keep
        $processed = $resultsSoFar.Count

        $elapsed = (Get-Date) - $startTime
        $rate = if ($elapsed.TotalSeconds -gt 0) {
            [math]::Round($processed / $elapsed.TotalSeconds, 2)
        }
        else { 0 }

        $eta = if ($rate -gt 0) {
            [math]::Round(($total - $processed) / $rate, 1)
        }
        else { 0 }

        $metrics = Get-DCLiveMetrics -Server $Server

        $percent = [math]::Round(($processed / $total) * 100, 2)

        Write-Progress `
            -Activity "Creating Demo Accounts" `
            -Status "Done: $processed/$total | $rate ops/s | ETA: $eta s | DC CPU: $($metrics.CPU)% | LDAP: $($metrics.LDAP)ms" `
            -PercentComplete $percent

        Start-Sleep -Milliseconds 250
    }

    # Final Results
    $finalResults = Receive-Job $job
    Remove-Job $job -Force

    Write-Progress -Activity "Creating Demo Accounts" -Completed

    $successCount = ($finalResults | Where-Object { $_.Success }).Count
    Invoke-Output -Type Success -Message "Finished creating demo users. Success: $successCount of $total."


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}