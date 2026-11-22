function Invoke-VerifyConfiguration {
    <#
    .SYNOPSIS
    Reviews the configuration of the AS2Go lab.

    .DESCRIPTION
    Checks the configured tools, accounts, Secure Access Workstation, and simulated AD backup share.
    Inventories directory assets, enterprise CAs, and the scenario ESC1 template. Checks the Web Enrollment
    Windows feature on the forest-root DC and zone transfer settings on the setup DNS server.
    Reports missing settings and failed queries while continuing with the other checks, then prints a
    final summary marking each check as Existing, Missing, or (if it could not be verified) Error.

    .PARAMETER Param1
    Reserved string parameter.

    .PARAMETER Param2
    Reserved string parameter.

    .PARAMETER CTPrefix
    Scenario prefix of the ESC1 certificate template. Defaults to AS2Go.

    .EXAMPLE
    Invoke-VerifyConfiguration -CTPrefix AS2Go
    Reviews the lab and checks for the AS2Go ESC1 certificate template.

    .OUTPUTS
    Console messages and inventory output.

    .COMPONENT
    Category: Main Function

    .FUNCTIONALITY
    Checks tools, accounts, workstation access, directory assets, AD CS, the backup share, and DNS zone transfers.
    Finishes with a summary reporting each check as Existing, Missing, or Error.
    #>
    param(
        [string]$Param1,
        [string]$Param2,
        [string]$CTPrefix = 'AS2Go'
    )

    $info = Measure-FunctionRuntime -Begin
    if (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message 'Verify the AS2Go lab configuration'
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $esc1TemplateName = "$CTPrefix ESC1"
    $checks = [ordered]@{
        'Lab tools'                                    = {
            $toolsPath = Get-ASConfig -Setting 'Tools'
            if ([string]::IsNullOrWhiteSpace($toolsPath)) {
                Write-AS2GoOutput -Type Warning -Message 'No tools folder is configured.'
            }
            elseif (-not (Test-Path -LiteralPath $toolsPath -PathType Container)) {
                Write-AS2GoOutput -Type Warning -Message "Tools folder is unavailable: $toolsPath"
            }
            else {
                foreach ($tool in 'NetSess.exe', 'Mimikatz.exe', 'Rubeus.exe', 'Certify.exe', 'PsExec.exe') {
                    if (Test-Path -LiteralPath (Join-Path $toolsPath $tool) -PathType Leaf) {
                        Write-AS2GoOutput -Type Bullet -Message "Found $tool"
                    }
                    else {
                        Write-AS2GoOutput -Type Warning -Message "Missing $tool in $toolsPath"
                    }
                }
            }
        }
        'Break-glass account'                          = {
            Get-BreakGlassAccount
        }
        'Secure Access Workstation'                    = {
            Write-AS2GoOutput -Type H1 -Message 'Secure Access Workstation'

            $workstation = Get-ASConfig -Setting 'AS2GoSAW'
            if ([string]::IsNullOrWhiteSpace($workstation)) {
                Write-AS2GoOutput -Type Warning -Message 'No Secure Access Workstation is configured.'
            }
            elseif (& {
                    $ProgressPreference = 'SilentlyContinue'
                    Test-NetConnection -ComputerName $workstation -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue -ProgressAction SilentlyContinue
                }) {
                Write-AS2GoOutput -Type Success -Message "WinRM is reachable on $workstation (TCP 5985)."
            }
            else {
                Write-AS2GoOutput -Type Warning -Message "WinRM is not reachable on $workstation (TCP 5985)."
            }
        }
        'Directory assets'                             = {
            $domainController = Get-BestDomainController -Domain (Get-ADDomain).DNSRoot
            if (-not $domainController) { throw 'No controller was found for the current domain.' }
            Get-TieringAssets -Server $domainController
            Get-AS2GoGroups -Server $domainController
            Get-DemoAccounts -Server $domainController
        }
        'Enterprise CAs and ESC1 certificate template' = {
            $rootController = Get-BestDomainController -Domain (Get-ADForest).RootDomain
            if (-not $rootController) { throw 'No controller was found for the forest root domain.' }
            Get-ADCSEnterpriseCA -Server $rootController -InventoryOnly
            Get-ADCSCertificateTemplates -Server $rootController -CTPrefix $esc1TemplateName -ExactMatch -InventoryOnly
        }
        'AD CS Web Enrollment feature'                 = {
            $rootController = Get-BestDomainController -Domain (Get-ADForest).RootDomain
            if (-not $rootController) { throw 'No controller was found for the forest root domain.' }
            
            Get-ADCSEnrollmentServices -Server $rootController 

        }
        'AD backup share'                              = {

            $backupShare = Get-ASConfig -Setting 'BackupShare'
            if ([string]::IsNullOrWhiteSpace($backupShare)) {
                Write-AS2GoOutput -Type Warning -Message 'No AD backup share is configured.'
            }
            elseif (-not (Test-Path -LiteralPath $backupShare -PathType Container)) {
                Write-AS2GoOutput -Type Warning -Message "AD backup share is unavailable: $backupShare"
            }
            else {
                Write-AS2GoOutput -Type H1 -Message 'AD backup share is configured.'
                foreach ($file in 'ntds.dit', 'daily-work.txt') {
                    if (Test-Path -LiteralPath (Join-Path $backupShare $file) -PathType Leaf) {
                        Write-AS2GoOutput -Type Bullet -Message "Found $file in $backupShare"
                    }
                    else {
                        Write-AS2GoOutput -Type Warning -Message "Missing $file in $backupShare"
                    }
                }
            }
        }
        'DNS zone transfers'                       = {
            $dnsServer = $Script:LogonServer
            if (-not $dnsServer) { throw 'No logon server is available for the DNS query.' }
            $rootDomain = (Get-ADForest).RootDomain
            $zones = @(Get-DnsServerZone -ComputerName $dnsServer | Where-Object {
                    $_.ZoneType -eq 'Primary' -and ($_.ZoneName -eq $rootDomain -or $_.ZoneName -like "*.$rootDomain")
                })
            if ($zones.Count -eq 0) {
                Write-AS2GoOutput -Type Warning -Message "No primary DNS zones for $rootDomain were found on $dnsServer."
            }
            foreach ($zone in $zones) {
                if ($zone.SecureSecondaries -eq 'TransferAnyServer') {
                    Write-AS2GoOutput -Type Bullet -Message "$($zone.ZoneName) on $dnsServer allows transfers to any server."
                }
                else {
                    Write-AS2GoOutput -Type Warning -Message "$($zone.ZoneName) on $dnsServer does not allow transfers to any server."
                }
            }
        }
        'MDI honeytoken'                           = {
            Get-Honeytoken
        }
    }

    $Summary = [ordered]@{}
    $ErrorActionPreference = 'Stop'
    foreach ($check in $checks.GetEnumerator()) {
        $checkWarnings = [System.Collections.Generic.List[object]]::new()
        try {
            # Stream 3 (Warning) is merged into the output stream and forwarded unchanged, so the
            # original console output is unaffected; only a copy is kept to derive the summary below.
            & $check.Value 3>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.WarningRecord]) { $checkWarnings.Add($_) }
                $_
            }
            $Summary[$check.Key] = if ($checkWarnings.Count -gt 0) { 'Missing' } else { 'Existing' }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "$($check.Key) could not be verified: $($_.Exception.Message)"
            $Summary[$check.Key] = 'Error'
        }
    }

    Write-AS2GoOutput -Type Header -Message 'Verification Summary'
    foreach ($entry in $Summary.GetEnumerator()) {
        switch ($entry.Value) {
            'Existing' { Write-AS2GoOutput -Type Success -Message "$($entry.Key): Existing" -NoExtraLines }
            'Missing' { Write-AS2GoOutput -Type Warning -Message "$($entry.Key): Missing" -NoExtraLines }
            'Error' { Write-AS2GoOutput -Type Error -Message "$($entry.Key): Could not be verified" }
        }
    }

    Write-AS2GoOutput -Type Info -Message 'Lab configuration review finished. See the results above.'
    Measure-FunctionRuntime -End -Details $info
}
