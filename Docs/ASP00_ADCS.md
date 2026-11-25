# ASP00 AD CS

Use **ADCS** in the public `Initialize-AS2GoLab` setup menu to review or prepare Active Directory Certificate Services for an authorized AS2Go lab. The menu calls the internal `Invoke-ADCSSetup` workflow; users start this setup through the public menu.

The workflow can install a forest-root Enterprise Root CA and Web Enrollment, or create and publish a new AS2Go ESC1 and ESC4 certificate-template pair. These options make significant changes to AD CS and Active Directory. Use them only in an isolated lab with explicit authorization.

## Workflow overview

- `Initialize-AS2GoLab` *(public setup command)*
  - **AS2Go - Environment Configuration** menu: select **ADCS**.
    - `Invoke-ADCSSetup` *(internal workflow)*
      - Review Enterprise CAs and enrollment services on a preferred forest-root domain controller.
      - Select **Install ADCS** to install missing roles, or **Add (and publish) Certificate Templates** to create an ESC1 and ESC4 pair.
      - Return to the ADCS menu to perform the other action or choose **Skip**.

## Menu option

```powershell
Initialize-AS2GoLab
```

Complete the setup prompts and select **ADCS**. The public setup command passes its `-Scenario` value to the private workflow as the certificate-template prefix. The default prefix is `AS2Go`.

Before presenting the menu, AS2Go inventories Enterprise CAs and enrollment services through a preferred domain controller in the forest-root domain. The initial menu choice defaults to **Install ADCS** when no enrollment service is found; otherwise it defaults to **Add (and publish) Certificate Templates**.

## Install AD CS

Choose **Install ADCS** to install missing roles on the preferred forest-root domain controller. If a role is already present, AS2Go reports that and does not reinstall it.

The installation configures:

| Role | Configuration |
|---|---|
| Certification Authority | Enterprise Root CA named `AS2GoRootCA`, 2048-bit key, SHA-256, 10-year validity. |
| Web Enrollment | AD CS Web Enrollment role and enrollment website. |

The role installation is performed remotely using PowerShell remoting. Afterward, AS2Go displays a manual follow-up task: configure the **Certificate Services Client - Auto-Enrollment** Group Policy setting under **Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies**. Enable it and select the options to renew expired certificates, update pending certificates, remove revoked certificates, and update certificates using certificate templates. AS2Go does not configure this policy for you.

## Add and publish certificate templates

Choose **Add (and publish) Certificate Templates** to create and publish a new ESC1 and ESC4 pair. AS2Go uses the configured scenario prefix and asks whether to use a timestamp suffix or enter a custom suffix. It displays matching existing AS2Go templates, but creates another pair; it does not modify or replace existing templates.

| Template | Lab configuration and effect |
|---|---|
| ESC1 | `Authenticated Users` can enroll; the template allows the enrollee to supply an arbitrary subject and includes Client Authentication. This is the intentionally vulnerable ESC1 demonstration. |
| ESC4 | `Authenticated Users` have full write access to the template object. The template is not created with ESC1-vulnerable properties, but its permissions allow template modification. |

The internal names use the pattern `<Scenario>-ESC1-<Suffix>` and `<Scenario>-ESC4-<Suffix>`. If multiple Enterprise CAs are registered, select one CA; if there is only one, AS2Go uses it. The new template objects are created in the forest Configuration naming context and then published on the selected CA. CA settings are not changed by the template-creation action.

If a generated template name already exists, AS2Go leaves it unchanged and reports failure for that pair. Review the reported names before trying again with a different suffix. After successful creation, AS2Go displays the created template names, display names, OIDs, and creation times.

## Requirements and operational impact

- Run setup from the elevated Enterprise Admin session described in [ASP00 Installation and Setup](ASP00-Setup.md). The operation needs rights to install Windows roles remotely and create or update certificate-template objects and CA publication entries in the forest.
- The setup computer needs the Active Directory and AD CS management components required by the workflow, access to the forest-root domain, and PowerShell remoting to the selected domain controller.
- Installing AD CS adds a CA and Web Enrollment service to the forest-root domain controller. Creating templates adds objects and permissions to the forest configuration partition and publishes the templates to an Enterprise CA.
- The ESC1 template permits broad enrollment with a supplied subject; the ESC4 template grants broad write access. Treat both as deliberately vulnerable lab objects and do not create them in production.
- The setup menu does not automatically roll back CA installation or template changes. `Remove-AS2GoLab -ADCS` offers a separate cleanup path: it removes templates tagged with the selected scenario prefix and decommissions `AS2GoRootCA`. It does not modify `NTAuthCertificates`; review and remove the exact CA certificate there manually if required.
- Use a coordinated lab snapshot and document which CA and templates were created before running cleanup.

## Related documentation

- [ASP00 Installation and Setup](ASP00-Setup.md)
- [ASP00 Verify Config](ASP00_VerifyConfig.md)
- [Public cleanup function: `Remove-AS2GoLab`](../Public/Remove-AS2GoLab.ps1)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Internal AD CS workflow: `Invoke-ADCSSetup`](../Private/ASP00/Invoke-ADCSSetup.ps1)
- [Certificate-template creation helper](../Private/ASP00/New-ESCxCertficateTemplate.ps1)
