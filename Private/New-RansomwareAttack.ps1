function New-RansomwareAttack {

    Param([string]$BackupShare)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    #prepare the simulation
    $TargetPath = $Script:DefautExfiltrationFolder
    $postfix = (Get-Date).toString("yyyyMMdd_HHmmss")
    $filePrefix = "RW-" + $postfix

    #create temp directory and fill the directory
    $FolderToEncrypt = "$BackupShare\$postfix"

    if (-not (Test-Path -Path $FolderToEncrypt)) {
        New-Item -Path $FolderToEncrypt -ItemType Directory -ErrorAction Ignore | Out-Null
    }

    if (-not (Test-Path -Path $FolderToEncrypt -PathType Container)) {
        Invoke-Output -Type Warning -Message "Unable to create folder '$FolderToEncrypt' - aborting simulation."
        Write-Log -Message "### Exit Function $CurrentFunction ###"
        return
    }

    Copy-Item "$TargetPath\*.*" -Destination $FolderToEncrypt -Exclude *.exe, *.ps1, .vs*

    # create info for the victim
    $newFile = "$TargetPath\$filePrefix.txt"
    (Get-Date).toString("yyyy-MM-dd HH:mm:ss") + "  | Hi user '$env:USERNAME', next time I will encrypt the complete Domain Controller."  | Out-File -FilePath $newFile 
    Get-Item $FolderToEncrypt\*.* | Out-File -FilePath $newFile -Append
    Copy-Item -Path "$TargetPath\$filePrefix.txt" -Destination $FolderToEncrypt -Recurse

    Invoke-Output -Type TextMaker -Message "Starting to encrypt all files in folder" -TextMaker $FolderToEncrypt

    $question = "Do you REALLY want to run this step? [Y/N] Default "
    $answer = Get-Answer -question $question -defaultValue $Script:No

    If ($answer -eq $Script:Yes) {
        $affectedDC = $BackupShare.split("\")[2]
        $sourceFile = Join-Path -Path $Script:ASSetup -ChildPath "Encryption\preview.html"
          
        Invoke-OutPut -Type Info -Message "Content of file '$FolderToEncrypt\$filePrefix.txt' before encryption:"
        Invoke-Item "$FolderToEncrypt\$filePrefix.txt"
        Invoke-FileEncryption -share $FolderToEncrypt
        Invoke-Output -Type Textmaker -Message "The following file is one of the files that were encrypted: --> " -TM "$FolderToEncrypt\$filePrefix.txt" 
        Invoke-Item "$FolderToEncrypt\$filePrefix.txt"

        foreach ($computer in $Script:AllDCs) {
            $affectedDC = $computer.FQDN
            Invoke-FakeRansomwarePopUp -ComputerName $affectedDC -SourceFile $sourceFile

        }

    }
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
