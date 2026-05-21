function Get-ADCSEnterpriseCA {

    ################################################################################
    #####                                                                      ##### 
    #####    Get all Enterprise CAs from AD                                    #####                      
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$Server
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    # Get all Enterprise CAs from AD

    $ConfigNC = (Get-ADRootDSE).ConfigurationNamingContext

    $cas = Get-ADObject -LDAPFilter "(objectClass=pKIEnrollmentService)" `
        -SearchBase "CN=Public Key Services,CN=Services,$ConfigNC"  `
        -Properties cn, dNSHostName, cACertificate, certificateTemplates, flags   `
        -Server $Server

    # Helper: build X509 objects from cACertificate (handles collections)
    function Get-CaCertificates {
        param([Microsoft.ActiveDirectory.Management.ADObject]$CaObject)

        $certs = @()

        foreach ($entry in $CaObject.cACertificate) {
            if ($entry -is [byte[]]) {
                try {
                    $certs += [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($entry)
                }
                catch {}
            }
        }

        $certs
    }

    # Build CA inventory with cert info
    $inventory = foreach ($ca in $cas) {
        $certs = Get-CaCertificates -CaObject $ca

        foreach ($cert in $certs) {
            [PSCustomObject]@{
                CAName       = $ca.cn
                Server       = $ca.dNSHostName
                Subject      = $cert.Subject
                Issuer       = $cert.Issuer
                Thumbprint   = $cert.Thumbprint
                NotBefore    = $cert.NotBefore
                NotAfter     = $cert.NotAfter
                IsSelfSigned = ($cert.Subject -eq $cert.Issuer)
                HasTemplates = ($ca.certificateTemplates -ne $null -and $ca.certificateTemplates.Count -gt 0)
                AD_Flags     = $ca.flags
            }
        }
    }

    # Build hierarchy: link issuing CAs to their parent by Subject/Issuer
    $roots = $inventory | Where-Object { $_.IsSelfSigned }
    $issuing = $inventory | Where-Object { -not $_.IsSelfSigned }

    $hierarchy = foreach ($ca in $inventory) {
        $parent = $null
        if (-not $ca.IsSelfSigned) {
            $parent = $roots + $issuing | Where-Object { $_.Subject -eq $ca.Issuer } | Select-Object -First 1
        }

        [PSCustomObject]@{
            CAName       = $ca.CAName
            Server       = $ca.Server
            Subject      = $ca.Subject
            Issuer       = $ca.Issuer
            IsRootCA     = $ca.IsSelfSigned
            HasTemplates = $ca.HasTemplates
            ParentCA     = if ($parent) { $parent.CAName } else { $null }
        }
    }

    # Check online/offline (simple ping)
    $servers = $hierarchy.Server | Sort-Object -Unique
    $status = foreach ($s in $servers) {
        $online = Test-Connection -ComputerName $s -Count 1 -Quiet -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Server = $s
            Online = $online
        }
    }

    # Join status back into hierarchy
    $final = $hierarchy | ForEach-Object {
        $st = $status | Where-Object { $_.Server -eq $_.Server } | Select-Object -First 1
        [PSCustomObject]@{
            CAName       = $_.CAName
            Server       = $_.Server
            Online       = $st.Online
            IsRootCA     = $_.IsRootCA
            HasTemplates = $_.HasTemplates
            ParentCA     = $_.ParentCA
            Subject      = $_.Subject
            Issuer       = $_.Issuer
        }
    }

    # Nice overview

    Invoke-Output -Type H1 -Message "Identitfied Enterprise CAs [$($final.count)]"
    if ($null -ne $final) {
        $final | Sort-Object IsRootCA, CAName | Format-Table CAName, Server, Online, HasTemplates, IsRootCA, ParentCA
        $Script:ADCSEnterpriseCAMissing = $false
    }
    else {
        Invoke-Output -Type Info -Message "No Enterprise CA found."
    }


    $4logfile = $final | Select-Object CAName, Server, Online, HasTemplates, IsRootCA, ParentCA | Sort-Object IsRootCA, CAName | Format-Table | Out-String
    Write-Log -Message "    >> Identified the following Get Enterprise CAs under Forest '$ConfigNC': $4logfile"


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}