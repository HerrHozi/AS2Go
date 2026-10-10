
<#
    .SYNOPSIS
        Disables ACL inheritance on a specific OU and removes all inherited permissions.

    .DESCRIPTION
        Equivalent to:
        Advanced Security Settings → Disable inheritance →
        "Remove all inherited permissions from this object"

        The operation is executed against a specific Domain Controller.

    .COMPONENT
    Category: Main Function

    .FUNCTIONALITY
    Disables OU ACL inheritance, removes inherited permissions, and returns the resulting ACL state.

    .PARAMETER OU
        Distinguished Name (DN) of the Organizational Unit.

    .PARAMETER Server
        Domain Controller to execute the operation against.

    .EXAMPLE
        Disable-ADOUInheritance `
            -OU "OU=Tier 0 Assets,DC=corp,DC=local" `
            -Server "DC01.corp.local"
    #>
function Disable-ADOUInheritance {

    ################################################################################
    #####                                                                      ##### 
    #####    Disables ACL inheritance on a specific OU                         #####
    #####    and removes all inherited permissions.                            #####                                 
    #####                                                                      #####
    ################################################################################

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogonServer
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type  Header -M "Disable AD OU Inheritance"

    $cname = Convert-FromDNToCN -DistinguishedName $TargetDN

    Invoke-Output -Type  TextMaker -M "Disabling inheritance on OU:" -Tm $cname

    Write-Verbose "Target OU DN : $TargetDN"
    Write-Verbose "Target DC    : $LogonServer"

    # --- Get Security Descriptor ---
    try {
        $TargetDNObject = Get-ADObject `
            -Identity $TargetDN `
            -Server $LogonServer `
            -Properties nTSecurityDescriptor
    }
    catch {
        throw "Failed to retrieve OU '$TargetDN' from server '$LogonServer'."
    }

    $acl = $TargetDNObject.nTSecurityDescriptor

    Write-Verbose "Current inheritance state: $($acl.AreAccessRulesProtected)"

    if ($PSCmdlet.ShouldProcess($TargetDN, "Disable inheritance and remove inherited permissions")) {

        # Disable inheritance and REMOVE inherited ACEs
        $acl.SetAccessRuleProtection($true, $false)

        try {
            Set-ADObject `
                -Identity $TargetDN `
                -Server $LogonServer `
                -Replace @{ nTSecurityDescriptor = $acl }
        }
        catch {
            throw "Failed to apply ACL changes to OU '$TargetDN'."
        }
    }

    # --- Verification ---
    $VerifyObject = Get-ADObject `
        -Identity $TargetDN `
        -Server $LogonServer `
        -Properties nTSecurityDescriptor

    $VerifyAcl = $VerifyObject.nTSecurityDescriptor

    [pscustomobject]@{
        OU                         = Convert-FromDNToCN -DistinguishedName $TargetDN
        InheritanceDisabled        = $VerifyAcl.AreAccessRulesProtected
        InheritedPermissionsRemain = [bool]($VerifyAcl.Access | Where-Object { $_.IsInherited })
    } | Out-Host

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

}
