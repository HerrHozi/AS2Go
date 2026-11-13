<#
.SYNOPSIS
Demonstrates certificate-based file encryption in a specified directory or share.

.DESCRIPTION
Checks that the supplied path exists and selects the first certificate under Cert:\LocalMachine with a
private key and a subject matching CN=<computer name>. followed by further subject-name text.
Enumerates all files recursively, including hidden files, and calls Start-FileEncryption for each file.
The helper reads the file into memory, saves a plain-text copy in Script:AS2GOTempDir, and overwrites the original
using AES-256-CBC with an RSA-protected session key. Missing paths or certificates stop the workflow.

.PARAMETER share
Directory or UNC share whose files are processed recursively. Supply an existing path accessible to the current user.

.EXAMPLE
Start-Encryption -share "\\DC01.example.com\AS2Go-EncryptionDemo"
Processes all files below the specified lab share using the matching machine certificate.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires an existing suitable RSA certificate; this function does not create or import one.
Temporary copies use only the source filename, so matching names in different directories can overwrite each other.
Author: AS2Go / me@mrhozi.com. License: MIT.
Credit: Encryption/FileStream pattern based on work by Ryan Ries.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Recursively encrypts files in the selected path using AES and an existing machine certificate.
Saves plain-text copies in the AS2Go temporary folder before overwriting the original files.
#>
Function Start-Encryption {
    param(
        [string] $share
    )

    $Info = Measure-FunctionRuntime -Begin

    If ((Test-Path -Path $share -PathType Any) -eq $false) {
        Write-AS2GoOutput -Type Warning -Message "Target path not found - aborting simulation: '$share'"
        return
    }

    Write-Host "`n"

    $cert = Get-ChildItem 'Cert:\LocalMachine' -Recurse |
    Where-Object {
        $_.HasPrivateKey -and
        $_.Subject -match "^CN=$([regex]::Escape($env:COMPUTERNAME))\."
    } |
    Select-Object -First 1

    if ($null -eq $cert) {
        Write-AS2GoOutput -Type Warning -Message "No matching computer certificate with a private key found - aborting file encryption."
        Write-Log -Message "File encryption aborted: No matching computer certificate with a private key found."
        return
    }

    Write-Log -Message "Simulation certificate found: $($cert.Subject) | $($cert.Thumbprint)"

    # Collect all files on the target share (simulation scope)
    $FilesToProcess = Get-ChildItem -Path $share -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { -not $_.PSIsContainer } |
    Select-Object -ExpandProperty FullName

    # Simulate encryption for each discovered file
    foreach ($file in $FilesToProcess) {
        Start-FileEncryption -FileToEncrypt $file -Cert $Cert -ErrorAction SilentlyContinue
    }

    Measure-FunctionRuntime -End -Details $Info
}

Function Start-FileEncryption {
    <#
    .Synopsis
        Encrypts a single file using AES-256-CBC with an RSA-encrypted session key.
        The file content is read into memory first, then the original is overwritten directly.
        A plain-text safety copy is saved to $Script:AS2GOTempDir before overwriting.
        The original can be restored using the private key of the provided certificate.
    #>
    Param(
        [Parameter(Mandatory)][System.IO.FileInfo]$FileToEncrypt,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
    )

    # Read entire file into memory so we can safely overwrite it in-place
    $plainBytes = [System.IO.File]::ReadAllBytes($FileToEncrypt.FullName)

    # Safety copy of the original to temp before overwriting
    $tempPath = [System.IO.Path]::Combine($Script:AS2GOTempDir, $FileToEncrypt.Name)
    [System.IO.File]::WriteAllBytes($tempPath, $plainBytes)

    # Set up AES-256-CBC and wrap the session key with the certificate's public RSA key
    $aes = [System.Security.Cryptography.AesManaged]::new()
    $aes.KeySize = 256
    $aes.BlockSize = 128
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC

    $keyFormatter = [System.Security.Cryptography.RSAPKCS1KeyExchangeFormatter]::new($Cert.PublicKey.Key)
    $encryptedKey = $keyFormatter.CreateKeyExchange($aes.Key, $aes.GetType())

    # File layout: [4 bytes keyLen][4 bytes ivLen][encryptedKey][iv][ciphertext]
    try {
        $writer = [System.IO.FileStream]::new($FileToEncrypt.FullName, [System.IO.FileMode]::Create)

        $writer.Write([System.BitConverter]::GetBytes($encryptedKey.Length), 0, 4)
        $writer.Write([System.BitConverter]::GetBytes($aes.IV.Length), 0, 4)
        $writer.Write($encryptedKey, 0, $encryptedKey.Length)
        $writer.Write($aes.IV, 0, $aes.IV.Length)

        $cryptoStream = [System.Security.Cryptography.CryptoStream]::new(
            $writer,
            $aes.CreateEncryptor(),
            [System.Security.Cryptography.CryptoStreamMode]::Write
        )

        $cryptoStream.Write($plainBytes, 0, $plainBytes.Length)
        $cryptoStream.FlushFinalBlock()
    }
    catch {
        Write-AS2GoOutput -Type Error "Encryption failed for '$($FileToEncrypt.FullName)': $_"
        return
    }
    finally {
        $cryptoStream?.Close()
        $writer?.Close()
        $aes.Dispose()
    }
    Write-AS2GoOutput -Type Bullet -Message "Encoded file" -TM $FileToEncrypt.FullName
}


