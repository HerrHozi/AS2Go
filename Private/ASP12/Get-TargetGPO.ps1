<#
.SYNOPSIS
Selects a target Group Policy Object.

.DESCRIPTION
Prompts the user to select a GPO, including linked GPOs, and returns the selected GPO.

.COMPONENT
Category: Sub Function

#>
function Get-TargetGPO {


    $info = Measure-FunctionRuntime -Begin

    $GPODN = Select-AdObject -Title "Select Target GPO" -IncludeLinkedGPOs

    If ($GPODN.Contains("cn=policies,cn=system")) {

        $GUID = (($GPODN -split ",")[0] -replace "cn=", "").replace("{", "").replace("}", "")
        $DOmainDN = ($GPODN -split "cn=system,")[-1]
        $DomainDNS = (Convert-FromDNToCN $DOmainDN).Replace("/", "")
        $server = Get-BestDomaincontroller -Domain $DomainDNS

        $Temp = (Get-GPO -Guid $GUID -Domain $DomainDNS -Server $server)

        $gpo = $null
        $gpo = [PSCustomObject]@{
            DisplayName = $Temp.DisplayName
            ID = $Temp.Id
            DomainDNS = $DomainDNS
            Server = $server
        }



        Write-Log -Message "    >> using $($gpo.DisplayName)"
    }
    else {
        Write-Log -Message "    >> no valid GPO selected"
        $gpo = $null
    }

    Measure-FunctionRuntime -End -Details $info
    return $gpo
}