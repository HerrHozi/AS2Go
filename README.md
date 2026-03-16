# AS2Go (Attack Scenario to Go)
![Module Type](https://img.shields.io/badge/type-PowerShell%20Module-orange)
![PowerShell](https://img.shields.io/badge/PowerShell-7.4%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Maintenance](https://img.shields.io/badge/status-active-brightgreen)

```Text
Author:          Holger Zimmermann | zimmermannn.holger@live.de
Current Version: 2026.2.26.773
Last Update:     2026-02-26
```

## Quick Start

### Load the PoSH Module

```PowerShell
import-module <ModulePath>\AS2Go.psd1
```

### Active Directory Security Assessment with BHCE (local machine, standard port)


```PowerShell
Invoke-SATypeActiveDirectory
```
### Active Directory Security Assessment with BHCE (custom server and port)

```PowerShell
Invoke-SATypeActiveDirectory -Neo4jDBServer 192.168.30.215 -Neo4jDBPort 7475
```

### Load Tier 0 objects only

```PowerShell
Import-SATier0Objects -ImportFolder 'c:\ADSA'
```

### Create a consideration list for potential Tier 0 objects (for customer review) 

```PowerShell
New-SATier0ConsiderationList
```


### Active Directory Security Assessment with BH4 (!)

```PowerShell
Invoke-SATypeActiveDirectory -Neo4jDBServer 127.0.0.1 -BH4
```

### Entra ID Security Assessement

```PowerShell
Invoke-SATypeEntraID -Neo4jDBServer 192.168.30.215
```

### Fastest detection of malicious SHA1 hashes via VirusTotal

```PowerShell
invoke-SATypeActiveDirectory -DataSourceCsvFileOnly -IncludeVirusTotalScan
```

### Import ADSA files (from a custom folder, overriding default '&lt;ModulePath&gt;\\..\\Import' folder)

```PowerShell
invoke-SATypeActiveDirectory -ImportFolder 'c:\ADSA' [-Recurse]
```

### Use a dedicated export folder
```PowerShell
invoke-SATypeActiveDirectory -Neo4jDBServer 192.168.30.215 -ExportFolder 'c:\temp\ADSA'
```


## DESCRIPTION

     This script launches an analysis for a security assessment
     by examining data from SharpHound, Group3r, and Active Directory
     configurations, including the analysis of ACLs on AD objects,
     SYSVOL folder permissions, and domain controller configurations.



## Functions

    - Open a connection to a Neo4j database
    - List, set, and clear high-value targets (HVTs, also known as Tier 0)
    - Mark high-value target group members as HVTs
    - Mark parent OUs of high-value targets as HVTs
    - Identify and mark GPOs that affect high-value objects as HVTs
    - Import and analyze CSV and Group3r.txt files
    - Query VirusTotal for malware using the SHA1 file hashes
    - Export all results to an Excel workbook

## Requirements

    - PoSH Version min. 7.1
    - BloodHound 4.x or BHCE 
    - ADSA Data Collection
    - Neo4j 4.x (incl. SharpHound Data)
    - Microsoft Excel
    - PoSH Module ASCIIWRITE
    - PoSH Module ImportExcel


## Script Parameter
```PowerShell
.PARAMETER ActiveComputerAccountsLast
Purpose: Modify the default value to detect the operating system of active computer accounts. Default is 90 days.

.PARAMETER BH4
Purpose: Use BloodHound 4.x instead of BloodHound CE

.PARAMETER CustomerVersion
Purpose: Remove irrelevant data for the customer on the summary page and save the report as 'Active Directory Security Assessment Additional Details - <forest>.xlsx'.

.PARAMETER DataSourceCsvFileOnly
Purpose: Use CSV files as the primary data source, ignoring Neo4j data.

.PARAMETER DataSourceNeo4jDB
Purpose: Select Neo4j DB as the primary data source.

.PARAMETER DebugMode
Purpose: No function in this version.

.PARAMETER DirectMembersOnly
Purpose: Consider only direct group members, excluding recursive members.

.PARAMETER EnableLogging
Purpose: Enable logging. The default log file is .\Invoke-SADataAnalysis.ps1.log.

.PARAMETER ExportFolder
Purpose: Specify an export folder, different from .\Export.

.PARAMETER ExportOnly
Purpose: Perform export operations only, without marking new objects as Tier 0.

.PARAMETER https
Purpose: Connect to the Neo4j instance via HTTPS.

.PARAMETER ImportFolder
Purpose: Specify the CSV import folder, different from .\Import.

.PARAMETER InactiveUserAccountsSince
Purpose: Export inactive user accounts (enabled but not logged in for a specified number of days). Default is 365 days.

.PARAMETER IncludeAdminTo
Purpose: Include AdminTo attack paths. By default, AdminTo flags groups but not their members.

.PARAMETER SkipConsiderADObjectAsTier0
Purpose: Skip exporting potential Tier 0 objects for customer analysis.

.PARAMETER IncludeInputForDrawIo
Purpose: Include data for Draw.IO to visualize the OU layout. This may consume significant resources in large AD environments.

.PARAMETER IncludeSuspiciousEdgesNonT0
Purpose: Export suspicious edges between non-Tier 0 users, groups, and computers to other non-Tier 0 objects.

.PARAMETER IncludeVirusTotalScan
Purpose: Check SHA1 file hashes in SYSVOL and autorun locations against VirusTotal using Sigcheck.

.PARAMETER IncludeWatermark
Purpose: Incorporate a watermark text on each worksheet; utilize the -watermarktext switch to specify a custom text.

.PARAMETER MultiForest
Purpose: Activate corresponding switches (and function) while analysis more than one forest in one run.

.PARAMETER Neo4jDBName
Purpose: Connect to a different Neo4j database.

.PARAMETER Neo4jDBPort
Purpose: Connect to the Neo4j instance on a port other than 7474.

.PARAMETER Neo4jDBPw
Purpose: Provide the Neo4j password (in clear text), useful for unattended execution.

.PARAMETER Neo4jDBServer
Purpose: Connect to a remote Neo4j instance (e.g., 192.168.44.44).

.PARAMETER Neo4jDBUser
Purpose: Connect to the Neo4j instance using a different user account.

.PARAMETER Plextrac
Purpose: Prepare worksheet '0 - PK Indicators Results' for integration with the Plextrac Report.

.PARAMETER Preview
Purpose: Test and preview new features.

.PARAMETER RandomColorSchema
Purpose: Use an alternative color schema for fun, if the default schema is not preferred.

.PARAMETER Recurse
Purpose: Retrieve all files in the CSV import folder and its subdirectories.

.PARAMETER SkipExportOfBottomUpApproach
Purpose: Skip the query that identifies the number of reachable high-value targets through broad groups. This query uses significant resources.

.PARAMETER SkipClearHost
Purpose: Prevent the console screen from being cleared during execution.

.PARAMETER SkipExportOfDCCHECKs
Purpose: Skip the Domain Controller Checks export. This process uses significant resources.

.PARAMETER SkipExportOfAttackPaths
Purpose: Skip the export of Attack Paths. This query consumes significant resources.

.PARAMETER SkipExportOfTier0GroupMembers
Purpose: Skip the export of high-value (Tier 0) role members, as this is not required at the moment.

.PARAMETER SkipExportOfOUStructure
Purpose: Skip the export of the OU Structure. This query uses significant resources.

.PARAMETER SkipExportOfRoleMembers
Purpose: Skip the export of high-value (Tier 0) group members, as this is not required at the moment.

.PARAMETER SkipExportOfTier0Objects
Purpose: Skip the export of all Tier 0 groups, as this is not required at the moment.

.PARAMETER SkipGroup3rFiles
Purpose: Skip the export of group3r results, as this is not required at the moment.

.PARAMETER SkipImportFromCSV
Purpose: Skip the import/export of CSV files, as this is not required at the moment.

.PARAMETER SkipExportOfInactiveUserAccounts
Purpose: Skip the export of inactive user accounts, as this is not required at the moment. This query uses significant resources.

.PARAMETER SkipPKFolder
Purpose: Skip the export of all PurpleKnight folder data. This process uses significant resources, especially in multi-forest assessments.

.PARAMETER SkipExportOfSpecialQueries
Purpose: Skip the export of Special Queries, as this is not required at the moment.

.PARAMETER SkipExportOfSuspiciousEdges
Purpose: Skip the export of Suspicious Edges, as this is not required at the moment.

.PARAMETER RemoveTier0Classification
Purpose: Reset already defined high-value targets, such as a service account for password resets.

.PARAMETER TextMarkerColor
Purpose: Highlight rows in the table with a different color (other than Magenta), used for Entra ID assessments.

.PARAMETER Unattended
Purpose: Run the script without user interaction.

.PARAMETER WatermarkText
Purpose: Specify a custom watermark text distinct from the default "Sample by Semperis!
```



### internal - update via git
#
```PowerShell
 $dir = "C:\Users\HolgerZimmermann\OneDrive - Semperis\AzureDevOps\SADA - Preview\BPR"
 Set-Location $dir
 git pull
 git status
 git add -A
 git commit -m "Version 0.0.16 is out - see also readme.md"
 git push
 ```
