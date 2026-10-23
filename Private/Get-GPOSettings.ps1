function Get-GPOSettings {

    ################################################################################
    #####                                                                      ##### 
    #####    Export GPO Settings in HTML File and open the file                #####                          
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $ID, 
        [string] $postfix, 
        [String] $name
    )

    $Info = Measure-FunctionRuntime -Begin

    if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
        Write-Log -Message "    >> GPO Name     $name"

        $htmlfile = Join-Path -Path $Script:AS2GoTempDir -ChildPath "GP-$ID-$postfix.html"
        $gporeport = Get-GPOReport -Guid $id -ReportType Html
        Set-Content -Value $gporeport -Path $htmlfile
        
        Invoke-Item $htmlfile 

        Invoke-output -type TextMaker -Message "Saved GPO settings for '$name' to" -TextMaker  $htmlfile     

    }
    else {
        invoke-output -type Warning -Message "To display the updated Group Policy Settings the GroupPolicy module is required!"
    }
    Measure-FunctionRuntime -End -Details $Info 
}
