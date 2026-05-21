function Set-gPCmachineExtensionNames {

    ################################################################################
    #####                                                                      ##### 
    #####  Modifiy attribute gPCmachineExtensionNames to display GPO settings  ##### 
    #####                                                                      #####
    ################################################################################

    # https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gppref/12512ed6-0632-4e90-a112-d3d2cd41df6c
    # https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpol/62d12924-6252-4052-996f-161d2b9019f4

    Param(
        [string] $GPOGUID, 
        [string] $CSEGUID, 
        [string] $TOOLGUID,
        [string] $server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    [bool]$skipUpdate = $false

    $GPOGUID = "{" + $GPOGUID + "}"

    $gpo = Get-AdObject -Filter 'ObjectClass -eq "groupPolicyContainer" -and Name -eq $GPOGUID' -Server $server -Properties * | Select-Object gPCmachineExtensionNames, DistinguishedName
    
    if ($null -eq $gpo.gPCmachineExtensionNames) {
        $gpo.gPCmachineExtensionNames = ""
    }

    Write-Log -Message "    >> current value $($gpo.gPCmachineExtensionNames)"

    if ($TOOLGUID -eq $ToolGUIDScheduledTask) {

        if ($gpo.gPCmachineExtensionNames.Contains($ToolGUIDScheduledTask)) {
            $skipUpdate = $true
        }
        else {
            $newvalue = New-GpCExtention -CSEGUID $Script:CSEGUIDScheduledTask -TOOLGUID $Script:ToolGUIDScheduledTask -OldValue $gpo.gPCmachineExtensionNames
        }
    }
    elseif ($TOOLGUID -eq $Script:ToolGUIDLocalUaG) {

        if ($gpo.gPCmachineExtensionNames.Contains($Script:ToolGUIDLocalUaG)) {
            $skipUpdate = $true
        }
        else {
            $newvalue = New-GpCExtention -CSEGUID $Script:CSEGUIDLocalUaG -TOOLGUID $Script:ToolGUIDLocalUaG -OldValue $gpo.gPCmachineExtensionNames
        }
    }
    elseif ($TOOLGUID -eq $Script:ToolGUIDComputerPolicySettings) {

        if ($gpo.gPCmachineExtensionNames.Contains($Script:ToolGUIDComputerPolicySettings)) {
            $skipUpdate = $true
        }
        else {
            $newvalue = New-GpCExtention -CSEGUID $Script:CSEGUIDSecurity -TOOLGUID $Script:ToolGUIDComputerPolicySettings -OldValue $gpo.gPCmachineExtensionNames
        }

    }
    else {

    }

    If ($skipUpdate -eq $false) {
        Set-ADObject -Identity $gpo.DistinguishedName -Replace @{gPCMachineExtensionNames = $newvalue } -Server $server
        Write-Log -Message "    >> set new value $newvalue"
    }
    else {
        Write-Log -Message "    >> no update required"
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

}
