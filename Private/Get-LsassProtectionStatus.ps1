<#
.SYNOPSIS
Reviews local LSASS protection and related Windows security services.

.DESCRIPTION
Reads LSASS process details, LSA registry configuration, Secure Boot, Device Guard,
Microsoft Defender status, and registered antivirus products. Evaluates possible reasons
for denied LSASS memory access without accessing process memory or changing security settings.

Wininit event 12 from the current boot confirms a protected LSASS startup; registry
configuration alone does not confirm the current process protection level.
SecurityCenter2 registration is not a complete EDR inventory and may be unavailable on servers.

.EXAMPLE
Get-LsassProtectionStatus
Displays local protection evidence and an English assessment. Run elevated for best coverage.

.LINK
https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection

.LINK
https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity

.COMPONENT
Category: Diagnostic Function

.FUNCTIONALITY
Reviews local LSASS protection, VBS, Credential Guard, memory integrity, Microsoft Defender,
and antivirus registration. Explains how observed protections may affect LSASS memory access
and identifies inconclusive evidence.
#>

function Get-LsassProtectionStatus {
    [CmdletBinding()]
    param()

    $info = Measure-FunctionRuntime -Begin

    $pplRuntimeConfirmed = $false
    $credentialGuardRunning = $false
    $vbsRunning = $false
    $defenderAvailable = $false
    $defenderRealTimeProtection = $false
    $defenderBehaviorMonitoring = $false
    $defenderEdrRunning = $false

    try {
        Write-AS2GoOutput -Type Header -Message 'LSASS Protection Status'
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        # ---------------------------------------------------------------------
        # Elevation context
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type Bullet -Message 'Process elevation context'

        $isElevated = $false
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Unable to determine elevation status: $($_.Exception.Message)" -NoExtraLines
        }

        if ($isElevated) {
            Write-AS2GoOutput -Type Success -Message 'The current PowerShell process is elevated. Full diagnostic coverage is expected.' -NoExtraLines
        }
        else {
            Write-AS2GoOutput -Type Warning -Message 'The current PowerShell process is not elevated. Secure Boot, event-log, Defender, and antivirus checks may be incomplete.' -NoExtraLines
        }

        # ---------------------------------------------------------------------
        # LSASS process details
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type H1 -Message "`nLSASS process details (these properties do not expose the PPL level)"

        $lsassProcess = $null
        try {
            $lsassProcess = Get-CimInstance -ClassName Win32_Process -Filter "Name='lsass.exe'" -ErrorAction Stop

            if ($lsassProcess) {
                $lsassProcess |
                Select-Object ProcessId, Name, CommandLine |
                Format-List |
                Out-Host
            }
            else {
                Write-AS2GoOutput -Type Warning -Message 'No LSASS process was returned; protection status remains unknown.' -NoExtraLines
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "LSASS process query unavailable: $($_.Exception.Message)" -NoExtraLines
        }

        # ---------------------------------------------------------------------
        # LSA registry configuration
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type H1 -Message "`nLSA registry configuration"

        

        $runAsPplValue = $null
        $runAsPplBootValue = $null
        $lsaCfgFlagsValue = $null

        try {
            $lsa = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -ErrorAction Stop

            foreach ($name in 'RunAsPPL', 'LsaCfgFlags', 'RunAsPPLBoot') {
                $property = $lsa.PSObject.Properties[$name]

                if ($null -eq $property) {
                    Write-AS2GoOutput -Type Bullet -Message "${name}: not configured in this registry key."
                }
                else {
                    Write-AS2GoOutput -Type Bullet -Message "${name}: $($property.Value)"

                    switch ($name) {
                        'RunAsPPL' { $runAsPplValue = $property.Value }
                        'LsaCfgFlags' { $lsaCfgFlagsValue = $property.Value }
                        'RunAsPPLBoot' { $runAsPplBootValue = $property.Value }
                    }
                }
            }

            switch ($runAsPplValue) {
                1 {
                    Write-AS2GoOutput -type Bullet -Message 'RunAsPPL is configured as 1: LSA protection is requested without a UEFI lock. A restart may be required; this is configuration evidence only.'
                }
                2 {
                    Write-AS2GoOutput -type Bullet -Message 'RunAsPPL is configured as 2: LSA protection is requested with a UEFI lock. A restart may be required; this is configuration evidence only.'
                }
                default {
                    Write-AS2GoOutput -type Bullet -Message 'RunAsPPL does not request protection in this registry key. This does not prove PPL is disabled: firmware configuration, policy, or Windows defaults may still enable it.'
                }
            }

            Write-AS2GoOutput -type Bullet -Message 'LsaCfgFlags and RunAsPPLBoot are configuration evidence, not proof of running Credential Guard or LSASS protection.'
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "LSA configuration unknown: $($_.Exception.Message)" -NoExtraLines
        }

        # ---------------------------------------------------------------------
        # Secure Boot
        # ---------------------------------------------------------------------
        try {
            $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
            Write-AS2GoOutput -Type Bullet -Message "Secure Boot enabled: $secureBoot. Secure Boot alone does not prove that an LSA-protection UEFI lock exists."
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Secure Boot status unknown (unsupported firmware or insufficient access is possible): $($_.Exception.Message)"
        }

        # ---------------------------------------------------------------------
        # Protected LSASS startup evidence
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type H1 -Message "`nProtected LSASS startup evidence"

        try {
            $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

            if ($null -eq $operatingSystem.LastBootUpTime) {
                throw 'The current boot time was not returned.'
            }

            $events = @(
                Get-WinEvent -FilterHashtable @{
                    LogName      = 'System'
                    ProviderName = 'Microsoft-Windows-Wininit'
                    Id           = 12
                    StartTime    = $operatingSystem.LastBootUpTime
                } -ErrorAction Stop
            )

            if ($events.Count -gt 0) {
                $pplRuntimeConfirmed = $true

                Write-AS2GoOutput -Type Success -Message 'Wininit event 12 confirms that LSASS started as a protected process during this boot. PPL can deny direct memory access even with administrator rights and SeDebugPrivilege.'

                $events |
                Select-Object TimeCreated, Id, Message |
                Format-List |
                Out-Host
            }
            else {
                Write-AS2GoOutput -Type Warning -Message 'No current-boot Wininit event 12 was returned. PPL runtime status remains unconfirmed.'
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "PPL startup evidence unavailable or absent; this does not prove protection is disabled: $($_.Exception.Message)"
        }

        # ---------------------------------------------------------------------
        # VBS / Credential Guard / HVCI
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type H1 -Message "`nVBS / Credential Guard / HVCI"

        try {
            $deviceGuard = Get-CimInstance `
                -ClassName Win32_DeviceGuard `
                -Namespace 'root\Microsoft\Windows\DeviceGuard' `
                -ErrorAction Stop

            if ($null -eq $deviceGuard -or
                $null -eq $deviceGuard.SecurityServicesRunning -or
                $null -eq $deviceGuard.VirtualizationBasedSecurityStatus) {
                throw 'Device Guard did not return the required runtime properties.'
            }

            $deviceGuard |
            Select-Object SecurityServicesConfigured, SecurityServicesRunning, VirtualizationBasedSecurityStatus |
            Format-List |
            Out-Host

            $vbsStatus = switch ($deviceGuard.VirtualizationBasedSecurityStatus) {
                0 { 'Not enabled' }
                1 { 'Enabled but not running' }
                2 { 'Enabled and running' }
                default { "Unknown value: $($deviceGuard.VirtualizationBasedSecurityStatus)" }
            }

            if ($deviceGuard.VirtualizationBasedSecurityStatus -eq 2) {
                $vbsRunning = $true
            }

            Write-AS2GoOutput -Type Bullet -Message "VBS: $vbsStatus."

            if ($deviceGuard.SecurityServicesRunning -contains 1) {
                $credentialGuardRunning = $true

                Write-AS2GoOutput -type Bullet -Message 'Credential Guard is running (service 1). It isolates protected credential material in a VBS-protected LSA context; ordinary LSASS memory does not contain those protected secrets. It does not protect every credential type.'
            }
            else {
                Write-AS2GoOutput -Type Bullet -Message 'Credential Guard is not reported as running (service 1). Registry configuration alone does not establish runtime status.'
            }

            if ($deviceGuard.SecurityServicesRunning -contains 2) {
                Write-AS2GoOutput -type Bullet -Message 'Memory integrity / HVCI is running (service 2). It enforces kernel code integrity; this is distinct from Credential Guard and does not itself confirm LSASS PPL.'
            }
            else {
                Write-AS2GoOutput -Type Bullet -Message 'Memory integrity / HVCI is not reported as running (service 2).'
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "VBS, Credential Guard and HVCI runtime status unknown: $($_.Exception.Message)"
        }

        # ---------------------------------------------------------------------
        # Microsoft Defender Antivirus and Defender for Endpoint
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type H1 -Message "`nMicrosoft Defender Antivirus status"

        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
            $defenderAvailable = $true

            $defenderStatus |
            Select-Object AMRunningMode,
            AMServiceEnabled,
            AntivirusEnabled,
            RealTimeProtectionEnabled,
            BehaviorMonitorEnabled,
            IoavProtectionEnabled,
            OnAccessProtectionEnabled,
            IsTamperProtected |
            Format-List |
            Out-Host

            if ($defenderStatus.RealTimeProtectionEnabled) {
                $defenderRealTimeProtection = $true
            }

            if ($defenderStatus.BehaviorMonitorEnabled) {
                $defenderBehaviorMonitoring = $true
            }

            $runningMode = if ($defenderStatus.AMRunningMode) {
                $defenderStatus.AMRunningMode
            }
            else {
                'Unknown'
            }

            Write-AS2GoOutput -Type Bullet -Message "Defender Antivirus running mode: $runningMode."

            if ($defenderRealTimeProtection) {
                Write-AS2GoOutput -type Bullet -Message 'Microsoft Defender real-time protection is enabled. It may block or alert on LSASS access or credential-dumping activity.'
            }
            else {
                Write-AS2GoOutput -type Bullet -Message 'Microsoft Defender real-time protection is disabled. This reduces the likelihood that Defender itself blocks LSASS access, but it does not rule out other endpoint controls.'
            }

            if ($defenderBehaviorMonitoring) {
                Write-AS2GoOutput -type Bullet -Message 'Microsoft Defender behavior monitoring is enabled. It may generate detections for suspicious process or credential-access behavior.'
            }
            else {
                Write-AS2GoOutput -Type Bullet -Message 'Microsoft Defender behavior monitoring is disabled.'
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Microsoft Defender Antivirus status unavailable: $($_.Exception.Message)" -NoExtraLines
        }

        Write-AS2GoOutput -Type Bullet -Message 'Microsoft Defender for Endpoint sensor status'

        try {
            $edrProcesses = @(Get-Process -Name 'Sense' -ErrorAction SilentlyContinue)

            if ($edrProcesses.Count -gt 0) {
                $defenderEdrRunning = $true
                Write-AS2GoOutput -Type Bullet -Message 'Microsoft Defender for Endpoint sensor process (Sense) is running.'
            }
            else {
                Write-AS2GoOutput -Type Bullet -Message 'Microsoft Defender for Endpoint sensor process (Sense) was not found. This does not prove that another EDR agent is absent.'
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Microsoft Defender for Endpoint sensor status unavailable: $($_.Exception.Message)" -NoExtraLines
        }

        # ---------------------------------------------------------------------
        # Registered antivirus products
        # ---------------------------------------------------------------------
        Write-AS2GoOutput -type Bullet -Message 'Registered antivirus products'

        try {
            $products = @(
                Get-CimInstance `
                    -Namespace 'root\SecurityCenter2' `
                    -ClassName AntiVirusProduct `
                    -ErrorAction Stop
            )

            if ($products.Count -gt 0) {
                $products |
                Select-Object displayName, productState |
                Format-Table -AutoSize |
                Out-Host
            }
            else {
                Write-AS2GoOutput -type Bullet -Message 'No antivirus registration was returned. This does not establish that AV or EDR is absent.'
            }
        }
        catch {
            Write-AS2GoOutput -Type Warning -Message "Antivirus registration unavailable (SecurityCenter2 may be absent on Windows Server): $($_.Exception.Message)" -NoExtraLines
        }

        Write-AS2GoOutput -type Bullet -Message 'Product names and raw productState values do not prove that AV/EDR blocked an operation. Correlate the failure time with product alerts and Windows logs.'

        # ---------------------------------------------------------------------
        # Build status lines for downstream prompts / reports
        # ---------------------------------------------------------------------
        $statusLines = @(
            if ($pplRuntimeConfirmed) {
                'PPL startup evidence was found for the current boot.'
            }
            else {
                'No PPL startup evidence was found for the current boot.'
            }

            if ($credentialGuardRunning) {
                'Credential Guard is running.'
            }
            else {
                'Credential Guard was not reported as running.'
            }

            if ($vbsRunning) {
                'VBS is enabled and running.'
            }
            else {
                'VBS was not reported as running.'
            }

            if ($defenderRealTimeProtection) {
                'Microsoft Defender real-time protection is enabled.'
            }
            else {
                'Microsoft Defender real-time protection was not reported as enabled.'
            }

            if ($defenderBehaviorMonitoring) {
                'Microsoft Defender behavior monitoring is enabled.'
            }
            else {
                'Microsoft Defender behavior monitoring was not reported as enabled.'
            }

            if ($defenderEdrRunning) {
                'Microsoft Defender for Endpoint is running.'
            }
            else {
                'Microsoft Defender for Endpoint was not reported as running.'
            }
        )

        $lsassMemoryAccessExpected = (
            -not $pplRuntimeConfirmed -and
            -not $credentialGuardRunning -and
            -not $vbsRunning -and
            -not $defenderRealTimeProtection -and
            -not $defenderBehaviorMonitoring -and
            -not $defenderEdrRunning
        )

        $assessment = if ($lsassMemoryAccessExpected) {
            'LSASS memory access is expected to succeed from an elevated process with SeDebugPrivilege, unless an unregistered endpoint protection product or another host-based control blocks it.'
        }
        elseif ($pplRuntimeConfirmed) {
            'LSASS PPL is confirmed for the current boot. Direct memory access from a standard elevated process is expected to fail with access denied, even when SeDebugPrivilege is available.'
        }
        elseif ($credentialGuardRunning) {
            'Credential Guard is running. Protected credential material is isolated in a VBS-protected LSA context and may not be available in ordinary LSASS memory.'
        }
        else {
            'One or more LSASS or endpoint protections were detected. LSASS memory access may be restricted or credential material may be isolated.'
        }

        Write-AS2GoOutput -Type H1 -Message "Assessment: $assessment"

        # Return exactly one result object to the pipeline.
        [PSCustomObject]@{
            ComputerName               = $env:COMPUTERNAME
            IsElevated                 = $isElevated
            LsassProcessId             = $lsassProcess.ProcessId
            PplRuntimeConfirmed        = $pplRuntimeConfirmed
            CredentialGuardRunning     = $credentialGuardRunning
            VbsRunning                 = $vbsRunning
            DefenderAvailable          = $defenderAvailable
            DefenderRealTimeProtection = $defenderRealTimeProtection
            DefenderBehaviorMonitoring = $defenderBehaviorMonitoring
            DefenderEdrRunning         = $defenderEdrRunning
            LsassMemoryAccessExpected  = $lsassMemoryAccessExpected
            StatusLines                = $statusLines
            Assessment                 = $assessment
        }


    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}


#If the NT hash is extracted on this host, direct LSASS memory access is expected to fail
#    because LSASS PPL is active. Credential Guard additionally isolates protected credential
#    material in a VBS-protected LSA context.