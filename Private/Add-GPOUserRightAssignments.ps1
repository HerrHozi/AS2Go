function Add-GPOUserRightAssignments {

    ################################################################################
    #####                                                                      ##### 
    #####      Add or Update User Rights Assignment                            #####                                 
    #####                                                                      #####
    ################################################################################


    Param(
        [string] $domainDNS,
        [string] $server,
        [string] $ID, 
        [String] $name
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    If (-not $SkipClearHost) { Clear-Host }

    Invoke-output -Type Header -Message "Add or Update User Rights Assignment"
    Invoke-Output -Type TextMaker -Message "Affected GPO" -TM "'$name' {$ID}"

    If ($UnAttended) {
        $answer = $Script:Yes 
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {
        write-host



        $infFilePath = "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf"
    
        If (!(Test-Path $infFilePath)) {
    
            New-Item -Name "Machine" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\\Policies\{$ID}" -ErrorAction Ignore | Out-Null
            New-Item -Name "Microsoft" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\\Policies\{$ID}\Machine" -ErrorAction Ignore | Out-Null
            New-Item -Name "Windows NT" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\\Policies\{$ID}\Machine\Microsoft" -ErrorAction Ignore | Out-Null
            New-Item -Name "SecEdit" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\\Policies\{$ID}\Machine\Microsoft\Windows NT" -ErrorAction Ignore | Out-Null
            
            Write-Log -Message "    >> created path: \\$server\SYSVOL\$domainDNS\\Policies\{$ID}\Machine\Microsoft\Windows NT\SecEdit"
                
            "[Unicode]" | Add-Content -Path $infFilePath
            start-sleep 1
            "Unicode=yes" | Add-Content -Path $infFilePath
            start-sleep 1
            "[Version]" | Add-Content -Path $infFilePath
            start-sleep 1
            'signature="$CHICAGO$"' | Add-Content -Path $infFilePath
            start-sleep 1
            "Revision=1" | Add-Content -Path $infFilePath 
            start-sleep 1
            Write-Log -Message "    >> created file: $infFilePath"

        }
        else {
            Write-Log -Message "    >> found file: $infFilePath"
        }
        

        Set-gPCmachineExtensionNames -GPOGUID $ID -CSEGUID $Script:CSEGUIDSecurity -TOOLGUID $Script:ToolGUIDComputerPolicySettings -server $server

        $FileContent = Get-Content -Path $infFilePath

        [bool]$PrivilegeRights = $false
        [bool]$SeDebugPrivilege = $false
        [bool]$SeTcbPrivilege = $false
        [bool]$SeRemoteInteractiveLogonRight = $false
        
        [int]$i = 0
        [string]$result = ""
        Foreach ($result in $FileContent) {
        
            If ($result.Equals("[Privilege Rights]")) {
                [string]$PrivilegeRightsV = $result
                [int]$PrivilegeRightsl = $i
                $PrivilegeRights = $true
            }
            elseif ($result.StartsWith("SeDebugPrivilege")) {
                $SeDebugPrivilege = $true
                [int]$SeDebugPrivilegeL = $i
                [string]$SeDebugPrivilegeV = $result
            }
            elseif ($result.StartsWith("SeTcbPrivilege")) {
                $SeTcbPrivilege = $true
                [int]$SeTcbPrivilegeL = $i
                [string]$SeTcbPrivilegeV = $result
            }
            elseif ($result.StartsWith("SeRemoteInteractiveLogonRight")) {
                $SeRemoteInteractiveLogonRight = $true
                [int]$SeRemoteInteractiveLogonRightL = $i
                [string]$SeRemoteInteractiveLogonRightV = $result
            }
            else {
            }
            $i++
        }
        
        If (-not $PrivilegeRights) {
            # no Privilege Rights available, create the whole set
            "[Privilege Rights]" | Add-Content -Path $infFilePath 
            "SeTcbPrivilege = *S-1-1-0" | Add-Content -Path $infFilePath 
            "SeDebugPrivilege = *S-1-1-0" | Add-Content -Path $infFilePath 
            "SeRemoteInteractiveLogonRight = *S-1-1-0"  | Add-Content -Path $infFilePath
            invoke-output -Type Success -Message "Added SeTcbPrivilege, SeDebugPrivilege and SeRemoteInteractiveLogonRight with trustee *S-1-1-0 (Everyone)" -noextralines
        }
        else {
            $updated = $false
            # just add or modify the SeRemoteInteractiveLogonRight trustee
            If (-not $SeRemoteInteractiveLogonRight) {
                $fileContent[$PrivilegeRightsl] += "`nSeRemoteInteractiveLogonRight = *S-1-1-0"
                $fileContent | Set-Content $infFilePath
                invoke-output -Type Success -Message "Added SeRemoteInteractiveLogonRight with trustee *S-1-1-0 (Everyone)" -noextralines
                $updated = $true
            }
            else {
                $fileContent[$SeRemoteInteractiveLogonRightL] = $SeRemoteInteractiveLogonRightV + ',*S-1-5-11'
                $fileContent | Set-Content -Path $infFilePath
                invoke-output -Type Success -Message "Modified SeRemoteInteractiveLogonRight with trustee *S-1-5-11 (Authenticated Users)" -noextralines
                $updated = $true
            }
        
            If (-not $SeTcbPrivilege) {
                $fileContent[$PrivilegeRightsl] += "`nSeTcbPrivilege = *S-1-1-0"
                $fileContent | Set-Content $infFilePath
                invoke-output -Type Success -Message "Added SeTcbPrivilege with trustee *S-1-1-0 (Everyone)" -noextralines
                $updated = $true
            }
            else {
                $fileContent[$SeTcbPrivilegeL] = $SeTcbPrivilegeV + ',*S-1-5-11'
                $fileContent | Set-Content -Path $infFilePath
                invoke-output -Type Success -Message "Modified SeTcbPrivilege with trustee *S-1-5-11 (Authenticated Users)" -noextralines
                $updated = $true
            }
            
            # just add or modify the $SeDebugPrivilege trustee
            If (-not $SeDebugPrivilege) {
                $fileContent[$PrivilegeRightsl] += "`nSeDebugPrivilege = *S-1-1-0"
                $fileContent | Set-Content $infFilePath
                invoke-output -Type Success -Message "Added SeDebugPrivilege with trustee *S-1-1-0 (Everyone)" -noextralines
                $updated = $true
            }   
            else {
                $fileContent[$SeDebugPrivilegeL] = $SeDebugPrivilegeV + ',*S-1-5-11'
                $fileContent | Set-Content -Path $infFilePath
                invoke-output -Type Success -Message "Modified SeDebugPrivilege with trustee *S-1-5-11 (Authenticated Users)" -noextralines
                $updated = $true
            }
        
            If ($updated -eq $false) {
                invoke-output -Type Info -Message "No changes needed, all privileges already assigned to *S-1-1-0 (Everyone) or *S-1-5-11 (Authenticated Users)" -noextralines
            }  
    
            if (-not $unAttended) { pause }
    
        }
    }
    else {
        Write-Log -Message "    >> Skipped!"
    }
                  
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
   
}
