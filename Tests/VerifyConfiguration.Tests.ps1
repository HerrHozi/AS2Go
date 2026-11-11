$privatePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Private'
. (Join-Path $privatePath 'Invoke-VerifyConfiguration.ps1')
. (Join-Path $privatePath 'Get-ADCSCertificateTemplates.ps1')
. (Join-Path $privatePath 'Get-Honeytoken.ps1')
. (Join-Path $privatePath 'Get-FunctionName.ps1')

# Stand-ins keep verification offline, including when the AD and DNS modules are installed.
function Measure-FunctionRuntime {
    param([switch]$Begin, [switch]$End, $Details)
    if ($Begin) { [pscustomobject]@{ FunctionName = (Get-FunctionName -StackNumber 2) } }
}
function Write-AS2GoOutput {
    param($Type, $Message, $TM)
    $script:messages.Add("$Type|${Message}|$TM")
}
function Write-Log { param($Message) }
function Get-ASConfig { param($Setting) $script:settings[$Setting] }
function Convert-FromDNToCN { param($DistinguishedName) $DistinguishedName }
function Get-BreakGlassAccount {}
function Get-ADDomain { @{ DNSRoot = 'child.example.test' } }
function Get-ADForest { @{ RootDomain = 'example.test' } }
function Get-BestDomainController { param($Domain) "dc.$Domain" }
function Get-TieringAssets { param($Server) $script:queries.Add("Tiering:$Server") }
function Get-AS2GoGroups { param($Server) $script:queries.Add("Groups:$Server") }
function Get-DemoAccounts { param($Server) $script:queries.Add("Demo:$Server") }
function Get-ADCSEnterpriseCA { param($Server, [switch]$InventoryOnly) $script:queries.Add("CA:${Server}:$InventoryOnly") }
function Get-ADRootDSE { param($Server) @{ ConfigurationNamingContext = 'CN=Configuration,DC=example,DC=test' } }
function Get-ADObject {
    param($LDAPFilter, $SearchBase, $Properties, $Server)
    $script:queries.Add("Templates:${Server}:$LDAPFilter")
}
function Test-NetConnection {
    param($ComputerName, $Port, $InformationLevel, $WarningAction)
    $script:queries.Add("WinRM:${ComputerName}:$Port")
    $script:winRMReachable
}
function Invoke-Command {
    param($ComputerName, $ScriptBlock)
    $script:queries.Add("WebEnrollment:$ComputerName")
    if ($script:remotingFails) { throw 'Access denied' }
    & $ScriptBlock
}
function Get-WindowsFeature {
    param($Name, $ErrorAction)
    if ($Name -ne 'ADCS-Web-Enrollment') { throw "Unexpected feature $Name" }
    @{ Installed = $script:webEnrollmentInstalled }
}
function Get-DnsServerZone {
    param($ComputerName)
    $script:queries.Add("DNS:$ComputerName")
    $script:zones
}

Describe 'Invoke-VerifyConfiguration' {
    BeforeEach {
        $script:SkipClearHost = $true
        $script:LogonServer = 'logon.child.example.test'
        $script:messages = [System.Collections.Generic.List[string]]::new()
        $script:queries = [System.Collections.Generic.List[string]]::new()
        $script:settings = @{
            BreakGlassAccount = 'CN=BreakGlass,DC=example,DC=test'
            Honeytoken = 'CN=Honey,DC=example,DC=test'
        }
        $script:winRMReachable = $true
        $script:webEnrollmentInstalled = $true
        $script:remotingFails = $false
        $script:zones = @()
        $script:ADCSASGoCTemplatesMissing = $false
        $script:CTemplates = 'existing setup state'
    }

    It 'checks the configured paths, selected workstation, directory targets and scenario prefix' {
        $script:settings.Tools = (New-Item -Path (Join-Path $TestDrive 'Tools') -ItemType Directory).FullName
        $script:settings.BackupShare = (New-Item -Path (Join-Path $TestDrive 'Backup') -ItemType Directory).FullName
        $script:settings.AS2GoSAW = 'paw.child.example.test'
        $null = New-Item -Path (Join-Path $script:settings.Tools 'Rubeus.exe') -ItemType File
        $null = New-Item -Path (Join-Path $script:settings.BackupShare 'ntds.dit') -ItemType File
        $script:zones = @(
            @{ ZoneName = 'example.test'; ZoneType = 'Primary'; SecureSecondaries = 'TransferAnyServer' }
            @{ ZoneName = '_msdcs.example.test'; ZoneType = 'Primary'; SecureSecondaries = 'NoTransfer' }
            @{ ZoneName = 'otherexample.test'; ZoneType = 'Primary'; SecureSecondaries = 'NoTransfer' }
        )

        Invoke-VerifyConfiguration -CTPrefix 'Demo(Lab)*'

        $results = $script:messages -join "`n"
        $results | Should Match 'Bullet\|Found Rubeus.exe'
        $results | Should Match 'Warning\|Missing Certify.exe'
        $results | Should Match 'Bullet\|Found ntds.dit'
        $results | Should Match 'Warning\|Missing daily-work.txt'
        $results | Should Match 'Success\|WinRM is reachable'
        $results | Should Match 'Success\|AD CS Web Enrollment feature is installed'
        $results | Should Match 'example.test on logon.child.example.test allows transfers'
        $results | Should Match '_msdcs.example.test on logon.child.example.test does not allow transfers'
        $results | Should Not Match 'otherexample.test'
        $results | Should Match 'Identified HoneyToken\|CN=Honey,'
        $results | Should Not Match 'Identified HoneyToken\|CN=BreakGlass,'
        ($script:queries -contains 'Tiering:dc.child.example.test') | Should Be $true
        ($script:queries -contains 'CA:dc.example.test:True') | Should Be $true
        ($script:queries -contains 'WebEnrollment:dc.example.test') | Should Be $true
        ($script:queries -contains 'WinRM:paw.child.example.test:5985') | Should Be $true
        ($script:queries -contains 'Templates:dc.example.test:(&(objectClass=pKICertificateTemplate)(name=Demo\28Lab\29\2a*))') | Should Be $true
        $script:CTemplates | Should Be 'existing setup state'
        $script:ADCSASGoCTemplatesMissing | Should Be $false
    }

    It 'warns about unset settings and continues after a remote query fails' {
        $script:remotingFails = $true
        $script:settings.Remove('Honeytoken')

        Invoke-VerifyConfiguration

        $results = $script:messages -join "`n"
        $results | Should Match 'Warning\|No tools folder is configured'
        $results | Should Match 'Warning\|No Secure Access Workstation is configured'
        $results | Should Match 'Warning\|AD CS Web Enrollment feature could not be verified: Access denied'
        $results | Should Match 'Warning\|No AD backup share is configured'
        $results | Should Match 'Warning\|No primary DNS zones'
        $results | Should Match 'Warning\|No Honeytoken identified'
        $results | Should Match 'Info\|Lab configuration review finished'
        $results | Should Not Match 'Success\|'
        ($script:queries -match '^WinRM:').Count | Should Be 0
    }

    It 'distinguishes negative results from query failures' {
        $script:settings.AS2GoSAW = 'offline.child.example.test'
        $script:settings.Tools = Join-Path $TestDrive 'MissingTools'
        $script:settings.BackupShare = Join-Path $TestDrive 'MissingShare'
        $script:winRMReachable = $false
        $script:webEnrollmentInstalled = $false

        Invoke-VerifyConfiguration

        $results = $script:messages -join "`n"
        $results | Should Match 'Warning\|Tools folder is unavailable'
        $results | Should Match 'Warning\|AD backup share is unavailable'
        $results | Should Match 'Warning\|WinRM is not reachable'
        $results | Should Match 'Warning\|AD CS Web Enrollment feature is not installed'
        $results | Should Not Match 'could not be verified'
    }
}
