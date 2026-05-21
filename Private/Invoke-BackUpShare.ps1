function Invoke-BackUpShare {

    ################################################################################
    #####                                                                      ##### 
    #####    Start Process to create and fill Share on Domain Controller       #####                              
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type Header -Message "Create a Share for 'fake' AD Backups on Domain Controller"

    $TargetServer = $Script:BestDCs[(Get-ADDomain).DNSRoot]

    Invoke-output -Type Bullet -Message "Target Domain Controller:" -TM $TargetServer
    New-BackUpShare -Server $TargetServer

    Copy-Item "$Script:ASSetup\ShareContent\*.*" -Destination "\\$TargetServer\AD-Backup" -Force
    Get-ChildItem -Path      "\\$TargetServer\AD-Backup" | Out-Host

    Invoke-Output -Type TextMaker -Message "Done - New Share is available" -TM  "\\$TargetServer\AD-Backup"
    
    Set-ASConfig -Setting "OfflineDITFile" -Value "\\$TargetServer\AD-Backup"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}