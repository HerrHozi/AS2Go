# Security Policy

## Purpose and authorized use

AS2Go (Attack Scenario to Go) is a dual-use Active Directory security training
framework for security awareness, detection engineering, and authorized purple
team exercises. Its intended purpose is to help defenders understand attack paths
and observe security telemetry in a controlled lab.

Run AS2Go only in isolated, non-production environments with explicit permission
from the owners of every affected system, account, and dataset. Permission must
cover the selected techniques and their potential impact. Do not use this project
for unauthorized access, unlawful attacks, or distribution of malicious payloads.

## Real effects of training scenarios

The term "simulation" describes the training purpose. It does not mean that all
operations are mocked, harmless, or automatically reversible. Depending on the
selected scenario, AS2Go can:

- Reset passwords, disable accounts, and remove group memberships.
- Create accounts, change permissions, and modify Group Policy or AD CS settings.
- Access credentials, export sensitive authentication material, and demonstrate
  Kerberos ticket abuse.
- Copy or export data and encrypt files, including overwriting original content.
- Disable Microsoft Defender real-time monitoring or configure exclusions.
- Execute tools and commands on lab systems, create scheduled tasks, or restart
  machines.

These operations can cause loss of access, service disruption, data loss, and
reduced security protection. Review the relevant source code before execution.
The authorization prompt is an acknowledgment, not a technical containment
boundary; directly invoked functions may not display it.

## Preparing a lab

- Use disposable lab systems, synthetic accounts, and non-sensitive sample data.
- Isolate the lab from production networks and identities.
- Take restorable snapshots and independent backups before running scenarios.
  Do not rely solely on temporary copies created by the module.
- Limit the scope and privileges to the requirements of the exercise.
- Treat logs, recordings, exported tickets, hashes, keys, and configuration files
  as potentially sensitive. Do not publish real credentials or customer data.
- After the exercise, restore affected systems and security settings, remove
  created artifacts, and rotate any exposed credentials as appropriate.

## Reporting a vulnerability

Send security reports privately to the project maintainer, Holger Zimmermann:

**[as2go@mrhozi.com](mailto:as2go@mrhozi.com)**

Use the subject `AS2Go security report`. Include, where possible:

- The affected version or commit and relevant files or functions.
- A description of the issue, its impact, and the expected behavior.
- Minimal reproduction steps using synthetic data in an authorized lab.
- Sanitized logs or screenshots and any suggested mitigation.

Do not include live passwords, tokens, private keys, credential dumps, or personal
data. Do not attach executable payloads or tool archives to the initial report.
If sensitive evidence is necessary, first request an appropriate transfer method.

Please allow time for assessment and coordinate public disclosure with the
maintainer. No response or remediation deadline is guaranteed. Reporting an issue
does not authorize testing against systems you do not own or have permission to
assess.

## Abuse and third-party concerns

Use the same email address for suspected misuse, accidental disclosure of
sensitive material, or concerns about bundled third-party tools and licensing.
Use the subject `AS2Go abuse or distribution concern` and provide relevant
repository links, file paths, and a factual description. Avoid sending victim
data or harmful attachments.

Public GitHub issues are suitable for general questions and non-sensitive bugs.
Please report exploitable vulnerabilities and abuse concerns privately first.

## Versions and third-party components

Report issues against any version and identify the affected revision. Assessment
and fixes focus on the current code; maintenance or backports for older releases
are not guaranteed.

Third-party tools and modules remain subject to their respective licenses and
security policies. The AS2Go license does not grant additional rights to those
components. A tool's inclusion or mention is not a guarantee of safety, integrity,
or permission to redistribute it. Obtain tools from their official sources and
verify their origin before use.
