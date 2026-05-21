function MySandbox {

Import-Module ActiveDirectory -Force

param(
    #[int[]]$RIDs = @(512, 519),  # Domain Admins, Enterprise Admins
    [switch]$Users,
    [switch]$Groups
)

# Alle Domains im Forest
$Forest = Get-ADForest
$Domains = $Forest.Domains


$Groups = $true

$Results = foreach($Domain in $Domains) {
    $DomainSID = (Get-ADDomain $Domain).DomainSID.Value
    write-host $DomainSID
        $rids = @('17281', '17282', '17283','512')
    
    foreach($RID in $RIDs) {
        $SearchSID = "$DomainSID-$RID"
        
        if($Groups) {
            # Gruppe zur SID finden
            $Group = Get-ADGroup -Filter "SID -eq '$SearchSID'" -Server $Domain #ä-ErrorAction SilentlyContinue
            if($Group) {
                [PSCustomObject]@{
                    Domain = $Domain
                    Type = 'Group'
                    Name = $Group.Name
                    SID = $Group.SID
                    DistinguishedName = $Group.DistinguishedName
                }
            $Group | ft
            }
        }
    }
    
}
$Group | ft


    $grouprids = @('17281', '17282', '17283','512')

    $groups = Get-ADGroup -Filter * -Properties CanonicalName, SID, SamAccountName, name `
        -SearchScope Subtree  | 
    Where-Object {
        ($_.SID.Value -split '-')[-1] -in $grouprids
    } |
    Select-Object CanonicalName, SID, SamAccountName, name, @{N = 'Domain'; E = { $_.CanonicalName.Split("/")[0] } } 

    $groups | Select-Object SamAccountName, CanonicalName, Domain | Sort-Object CanonicalName  | out-host

$Results | Format-Table -AutoSize
#$Results | Export-Csv "Forest-RID-$((Get-Date).ToString('yyyyMMdd')).csv" -NoTypeInformation


<#
d
#>
}