function Get-AuthorInfo {
    param([switch]$Preview, [switch]$SafeMode)

    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Get-AuthorInfo' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

    Write-AS2GoOutput -Type Header -Message "About me"

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
            GitHub           = 'https://github.com/HerrHozi'
            Community        = 'https://www.powershellgallery.com/profiles/HerrHozi'
            wWWHomePage      = 'https://HerrHozi.com'
        }
    )

    write-host "`n`n`n`n"

    $SandboxProfile | fl

    write-host "`n`n"

    $title = "PoSH User Group | AS2Go | Presentation"
    $message = "Select the action to execute. Options with unmet requirements are hidden."

    $Options = @(
        [pscustomobject] @{
            Label = "&First Slide"
            Help  = 'Go to the first slide'
            Value = 'First'
        },
        [pscustomobject] @{
            Label = "&Previous Slide"
            Help  = 'Go to the previous slide'
            Value = 'Previous'
        },
        [pscustomobject] @{
            Label = "&Next Slide"
            Help  = 'Go to the next slide'
            Value = 'Next'
        },
        [pscustomobject] @{
            Label = "&Last Slide"
            Help  = 'Go to the last slide'
            Value = 'Last'
        },
        [pscustomobject] @{
            Label = "E&xit"
            Help  = 'Exit the presentation'
            Value = 'Exit'
        }
    )

    $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 2 -Title $title



    If ($answer -eq 'Exit') {
        return
    }
    clear-host
    Start-PsUserGroupSession -SafeMode

}

