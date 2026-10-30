function Get-AuthorInfo {
    param([switch]$Preview)

    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Get-AuthorInfo' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }



    $SandboxProfile = @(
        [pscustomobject]@{
            WhenCreated      = [datetime]'2022-07-01 09:00:00'
            Name             = 'Holger Zimmermann'
            Title            = 'Senior Security Consultant'
            Department       = 'Breach Preparedness & Response'
            Specialization   = 'Active Directory & Entra ID Security'
            Focus            = 'Security Assessments & Attack Path Analysis'
            Mail             = 'holgerz@semperis.com'
            AttackSimulation = 'AS2Go'
            'YearsInIT (AD)' = '25+'
            CurrentMission   = 'Make Active Directory Misconfiguration Visible'
            seeAlso          = 'https://github.com/HerrHozi'
            wWWHomePage      = 'https://HerrHozi.com'
        }
    )

    return $SandboxProfile
}