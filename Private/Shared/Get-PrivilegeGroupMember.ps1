function Get-PrivilegeGroupMember {

    Param([PSCustomObject[]] $Group)

    $Info = Measure-FunctionRuntime -Begin

    Try {
        $members = Get-ADGroupMember -Server $Group.FQDN -Identity $Group.SID -Recursive | Select-Object objectClass, SamAccountName, @{N = "CanonicalName"; E = { Convert-FromDNToCN -DistinguishedName $_.distinguishedName } } 
        $members | Select-Object -first 10  | Out-Host
        $4logfile = $members | Format-Table | Out-String
        Write-Log -Message $4logfile
   
    }
    catch {
        Write-Host "   [x] No ACCESS to group '$group'`n`n" -ForegroundColor $Script:FGCError
    }

    Write-Log -Message "    >> using $($Group.SID) from domain $($Group.FQDN)"
    Measure-FunctionRuntime -End -Details $Info
}
