# AS2Go (Attack Scenario to Go) - Version 2026
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
