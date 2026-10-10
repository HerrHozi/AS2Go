<#
.SYNOPSIS
Converts a distinguished name to canonical Active Directory path format.

.DESCRIPTION
Decodes escaped distinguished-name components and returns the corresponding canonical AD path.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Decodes escaped DN components and returns the corresponding canonical path.
#>
function Convert-FromDNToCN {

    ################################################################################
    #####                                                                      ##### 
    #####    Convert a Distinguished Name (DN) to a Canonical Name format.     #####                                 
    #####                                                                      #####
    ################################################################################

    param (
        [Parameter(Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [string]$DistinguishedName
    )
    process {
        # NB: Escapaing special characters
        # https://social.technet.microsoft.com/wiki/contents/articles/5312.active-directory-characters-to-escape.aspx

        # Characters escaped in DistinguishedName: ',\#+<>;"= as well as leading/trailing spaces
        # Characters escaped in CanonicalName: /\

        # NB: This version of the fuction intentionally not taking care about decoding "\OACNF" part of RDN
        # Example demonstrating incorrect convertion:
        # 'CN=user\0ACNF:bc598594-2dd2-4525-8fd4-4aff689de511,OU=Test,DC=domain,DC=com' | ConvertFromDN

        # NB: This version of the function is not taking care about decoding non-UTF-8 characters

        #if ($EnableLogging) { Write-Log -Message "    >> Convert from: $DistinguishedName" }

        if ($DistinguishedName) {
            $d = ''; $p = '';
            $DistinguishedName -split '(?<!\\),' <# ignoring escaped commas #> | ForEach-Object {
                if ($_ -match '^DC=') {
                    $d += $_.Substring(3) + '.'
                }
                else {
                    $escaped = $_.Substring(3)
                    $cleaned = $escaped.Replace('\,', ',').Replace('\\', '\').Replace('\#', '#').Replace('\+', '+').Replace('\<', '<').Replace('\>', '>').Replace('\;', ';').Replace('\"', '"').Replace('\=', '=') -replace '^(\\ )(.+)$', ' $2' -replace '^(.+)(\\ )$', '$1 '
                    $encoded = $cleaned.Replace('\', '\\').Replace('/', '\/')
                    $p = $encoded + '/' + $p
                }
            }
            $cn = $d.TrimEnd('.') + '/' + $p.TrimEnd('/')
        }
        #if ($EnableLogging) { Write-Log -Message "    >> Convert to:   $cn" }
        return $cn
    }
    
}
