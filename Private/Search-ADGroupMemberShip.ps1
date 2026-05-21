function Search-ADGroupMemberShip {

    ################################################################################
    #####                                                                      ##### 
    #####    check if name (AD Object is member of a special group             #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $name, [string] $rID)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    [bool]$result = $false

    If ([string]::IsNullOrEmpty($name) -or [string]::IsNullOrEmpty($rID)) {
        return $false
    }
     
    try {

        $dc = [System.Net.Dns]::GetHostByName(($env:logonserver).replace("\","")).HostName
        $results = Get-ADPrincipalGroupMembership -Identity $name -ResourceContextServer $dc -ResourceContextPartition (get-addomain).DistinguishedName | Select-Object sid, name -ErrorAction Stop
        $temp = $results | Where-Object { $_.sid -like "*$rID" } | Select-Object name
        If ($temp) { $result = $true }

    }
    catch {

        try {
            $tempGroupName = Get-ADGroupSamAccountNameBasedOnRID -RID $rID
            $results = Get-AdGroupMember -Identity $tempGroupName
            $temp = $results | Where-Object { $_.name -like "*$name" } | Select-Object name -ErrorAction Stop
            If ($temp) { $result = $true }
        }
        catch {
            <#Do this if a terminating exception happens#>
            Invoke-Output -Type Error -Message "$_"
        }
    }
        
    Write-Log -Message "    >> $name is memberof $rID - $result"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result
}
