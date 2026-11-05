# AS2Go – External Tools

AS2Go-Tools_v2.zip and AS2Go-Tools_v2.7z (PW: HerrHozi!)

This document lists the sources for the external tools used with AS2Go.
The links point to the respective project or download pages. Download the latest
available version from each source and select the appropriate Windows architecture.
Executable files are not included with this README.

## Downloads and Project Pages

| Tool / Filename | Source | Notes |
| --- | --- | --- |
| `mimikatz.exe` | [Mimikatz – Releases](https://github.com/gentilkiwi/mimikatz/releases/) | Download a release archive and extract the appropriate executable. |
| `NetSess.exe` | [NetSess – joeware](https://www.joeware.net/freetools/tools/netsess/) | Download it from the publisher's website. |
| `PsExec.exe` | [PsExec – Microsoft Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec) | Included in the **PsTools** package. |
| `Certify.exe` | [Certify – GhostPack](https://github.com/GhostPack/Certify/) | Source code and build instructions are available in the repository; this is not a direct EXE download link. |
| `Rubeus.exe` | [Rubeus – GhostPack](https://github.com/GhostPack/Rubeus/) | Source code and build instructions are available in the repository; this is not a direct EXE download link. |


## Tested with

The following versions were used for testing:

| Tool | Release | Last Build |
| --- | --- | --- |
| `NetSess.exe` | 2.0.0.46 | 20220105 |
| `Mimikatz.exe` | 2.2.0.0 | 20220809 |
| `Rubeus.exe` | 2.3.3.0 | 20251009 |
| `Certify.exe` | 2.0.0.0 | 20251009 |
| `PsExec.exe` | 2.4 | 20220719 |

These are the tested versions, which may differ from the latest available releases.

## Setup

1. Open the relevant source linked above.
2. Download the available package or follow the project's build instructions.
3. Extract the package and confirm that the required executable is present.
4. Place the files in the tools directory specified by your AS2Go configuration.

“Latest” refers to the version currently available from the linked source.
This README does not specify fixed version numbers.
The table above records the tested versions; the download links point to the available releases.