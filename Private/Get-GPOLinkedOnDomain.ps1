function Get-GPOLinkedOnDomain {

    ################################################################################
    #####                                                                      ##### 
    #####    List all GPO which Linked directly on the Domain                  #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################


    $dn = Select-ADObject -DomainSelectionOnly -Title "Select Domain for GPO Manipulation"
    $server = Get-BestDomainController -domain $dn
    $cn = Convert-FromDNToCN -DistinguishedName $dn

    $LinkedGPOs = New-Object System.Collections.ArrayList
    $domain = $cn.Split('/')[0]
    $results = (Get-ADObject -Filter { ObjectClass -eq "domainDNS" } -Server $server -Properties * -SearchBase $dn -SearchScope Base | Select-Object name, gplink)

    $number = ($results.gplink.Split(']')).count - 1

    Write-Log -Message "    Found $number GPOs linked directly on Domain $domain"

    [int]$i = 0
    [string]$result = ""

    Foreach ($result in $results.gplink.Split(']')) {

        [int]$start = $result.IndexOf('{') + 1
        [int]$end = $result.IndexOf('}') - $start

        If ($end -eq -1) { break }

        $id = $result.Substring($start, $end) 
        Write-Log -Message "    Handling GPO with GUID $id"

        $gpos = (Get-GPO -Guid $id -Domain $domain -Server $server | Select-Object  Id, DisplayName, GpoStatus, Description, ModificationTime, Owner)

        $items = @{
            Number           = $i
            DisplayName      = $gpos.DisplayName
            GpoStatus        = $gpos.GpoStatus
            Description      = $gpos.Description
            ID               = $gpos.Id
            Owner            = $gpos.Owner
            ModificationTime = $gpos.ModificationTime
        }
                    
        $LinkedGPOs.add((New-Object psobject -Property $items)) | Out-Null
        $i++
    }

    $i = $LinkedGPOs.Count
    If (-not $SkipClearHost) { Clear-Host }

    Invoke-Output -Type Header -Message "GPT Manipulation on Domain $domain"

    $LinkedGPOs | Sort-Object Number | Select-Object Number, Displayname, ID, GPOStatus, Description, Owner, ModificationTime | Format-Table | Out-Host

    Invoke-Output -Type Success -Message "Identified $i GPOs directly linked to Domain"

    $i -= 1

    do {
        do { 
            $question = "Enter the number of the Group Policy whose INF files you want to modify, for example 0. Default "
            $gpo = Get-Answer -question $question -defaultValue 0

            if ($gpo -match '^\d+$' -and ([int]$gpo -ge 0 -and [int]$gpo -le $i)) {
                $repeat = $Script:No
            }
            else {
                $repeat = $Script:Yes
                Write-Host "`n     $gpo" -NoNewline -ForegroundColor Red
                Write-Host " is out of scope!"
            }

        } Until ($repeat -eq $Script:No)

        Get-GPOSettings -ID $LinkedGPOs[[int]$gpo].ID -Name $LinkedGPOs[[int]$gpo].DisplayName -postfix 'before'

        $title = "REPEAT | GPO Selection"
        $repeat = Show-DecisionPrompt -Default 1 -Title $title
    } Until ($repeat -eq $Script:No)

    $TargetGPO = [pscustomobject]@{
        DisplayName = $LinkedGPOs[[int]$gpo].DisplayName
        ID          = $LinkedGPOs[[int]$gpo].ID
        Server      = $server
        DomainDNS   = $domain
    }

    Write-Log -Message "    >> using GPO $($LinkedGPOs[[int]$gpo].DisplayName) {$($LinkedGPOs[[int]$gpo].ID)}"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $TargetGPO
}
