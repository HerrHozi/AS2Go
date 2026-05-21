function Get-GPOSettings {

    ################################################################################
    #####                                                                      ##### 
    #####    Export GPO Settings in HTML File and open the file                #####                          
    #####                                                                      #####
    ################################################################################

    Param([string] $ID, [string] $postfix, [String] $name)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    if (Get-Module -ListAvailable -Name GroupPolicy) {
        Write-Log -Message "    >> GPO Name     $name"

        $htmlfile = ".\GP-$ID-$postfix.html"
        $gporeport = Get-GPOReport -Guid $id -ReportType Html
        Set-Content -Value $gporeport -Path $htmlfile
        Invoke-Item $htmlfile 

        Write-host "`nSaved the selected GPO " -NoNewline
        Write-host "$name " -NoNewline -ForegroundColor Yellow
        Write-Host " settings to file $htmlfile."

        Write-Log -Message "    >> GPO Settings $htmlfile "
        #endregion ####################### main code #########################

        $runtime = Get-RunTime -StartRunTime $StartRunTime
        Write-Log -Message "    Run Time: $runtime [h] ###"
        Write-Log -Message "### End Function $CurrentFunction ###"
    }
    else {

        invoke-output -type Warning -Message "To display the Group Policy Settings the GroupPolicy module is required!"
    }
    # return $true
}
