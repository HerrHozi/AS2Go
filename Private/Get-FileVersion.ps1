function Get-FileVersion {

    Param(
        [Parameter(Mandatory = $True)][string]$fullname
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ((Test-Path -Path $fullname -PathType Leaf) -eq $false) {
        $release = "failed"
        #       Write-Host "WARNING: Cannot find file - $fullname!" -ForegroundColor $Script:FGCWarning
        #       Write-Log -Message "WARNING: Cannot find file - $fullname!" -level WARN

        Invoke-Output -T Warning -M "Cannot find file - $fullname!"

        If ($fullname.ToUpper() -eq $Script:ConfigFile.ToUpper()) {
            Write-Host "`n`nProbably you started the PoSH Script $scriptName `nfrom the wrong directory $Script:ConfigFile!" -ForegroundColor $Script:FGCError
            return
        }
    }
    else {
        [datetime] $LastWriteTime = (get-item $fullname).LastWriteTime
        [String]   $FileVersion = (get-item $fullname).VersionInfo.FileVersion
        $build = Get-date -date $LastWriteTime -Format yyyyMMdd
        $release = ("Release: " + $FileVersion.PadRight(9, [Char]32) + "(last build $build)")
        Write-Log -Message "    >> Version of $fullname is $release!"
    }


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
    return $release 
}
