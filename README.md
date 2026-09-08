# PowerShellScripts

A personal collection of PowerShell scripts for automation, administration, and DevOps tasks.

## Overview

This repository contains standalone PowerShell scripts developed for various administrative and automation tasks, including:

- Azure DevOps activity reporting (project and repository level)
- Microsoft 365/Office 365 user management
- Network utilities and diagnostics
- Server administration (Windows Server 2016+)
- Packaging utilities for PowerShell modules

## Prerequisites

- **PowerShell Version**: PowerShell 5.1 or PowerShell 7+ (the Azure DevOps scripts require 7.0+)
- **Required Modules** (per script):
  - `Az.Accounts` (Azure PowerShell) - Azure DevOps scripts, for `Get-AzAccessToken`
  - `MSOnline` - `reset_password_o365.ps1` (installs it if missing)
  - `PowerShellGet` - `New-NuspecFromPsd.ps1`

Install required modules:
```powershell
Install-Module -Name Az.Accounts -Scope CurrentUser
Install-Module -Name MSOnline -Scope CurrentUser
```

## Repository Structure

```
PowerShellScripts/
├── Scripts/              # Standalone utility scripts
│   ├── AzureDevOps/      # Azure DevOps activity reports
│   ├── General/          # General scripts
│   ├── Office365/        # Office365 specific scripts
│   ├── Server 2016/      # Server 2016-specific scripts and how-to notes
│   └── Utility/          # Packaging helpers
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

## Quick Start

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/jinyeow/PowerShellScripts.git
   cd PowerShellScripts
   ```

2. **Run scripts directly from their location**:
   ```powershell
   # Rank Azure DevOps projects by activity
   .\Scripts\AzureDevOps\Get-AdoProjectActivity.ps1 -Organization "https://dev.azure.com/YourOrg"

   # Reset an Office 365 password (prompts for the user's email)
   .\Scripts\Office365\reset_password_o365.ps1
   ```

## Key Scripts

### Azure DevOps

Both scripts are read-only, run interactively, and require PowerShell 7+. They dot-source `Invoke-AdoRestMethodWithRetry.ps1` (and `Get-AdoBranchPolicyEligibleRepository.ps1` for the project report) from `Scripts/AzureDevOps/Private/` within this repository.

**`Get-AdoProjectActivity.ps1`** - Ranks every project in an organisation by pull-request and push recency, least disruptive first, to sequence a branch-policy rollout. Emits one row per project with a `RiskBucket` (`NoRepositories`, `NoPullRequestsNoPushes`, `PullRequestHistory`, `NoPullRequestsRecentPushes`, `Failed`).
```powershell
.\Scripts\AzureDevOps\Get-AdoProjectActivity.ps1 -Organization "https://dev.azure.com/YourOrg" | Format-Table -AutoSize
.\Scripts\AzureDevOps\Get-AdoProjectActivity.ps1 -Organization "https://dev.azure.com/YourOrg" | Export-Csv -Path .\project-activity.csv -NoTypeInformation
```

**`Get-AdoRepositoryActivity.ps1`** - Reports per-repository push activity and top pusher(s) for one project. Emits one row per repository (disabled repositories included) with an `ActivityBand` (`Active`, `Slowing`, `WindingDown`, `Dormant`, `Never`, `Unknown`) and optionally writes a CSV.
```powershell
.\Scripts\AzureDevOps\Get-AdoRepositoryActivity.ps1 -Organization "https://dev.azure.com/YourOrg" -ProjectName "Project Name" -Verbose | Format-Table -AutoSize
.\Scripts\AzureDevOps\Get-AdoRepositoryActivity.ps1 -Organization "https://dev.azure.com/YourOrg" -ProjectName "Project Name" -OutFile .\repo-activity.csv
```

### Network Utilities

**`network_scan.ps1`** - Scans `192.168.2.1-255` for port 9100 using `Test-RemotePort` (the subnet and port are hard-coded; `Test-RemotePort` must be available in the session).
```powershell
.\Scripts\General\network_scan.ps1
```

### Microsoft 365 Administration

**`reset_password_o365.ps1`** - Connects to MSOnline, prompts for a user's email and resets the password. The `Set-MsolUserPassword` call runs with `-WhatIf`; remove it to apply the change.
```powershell
.\Scripts\Office365\reset_password_o365.ps1
```

### Server 2016

Mostly annotated how-to notes and small helpers; read each file before running.

- **`Rename-Domain.ps1`** - Steps for renaming an AD domain (`rendom`, `netdom`, `gpfixup`, DNS)
- **`Set-NanoServerConfiguration.ps1`** - Build and configure a Nano Server image
- **`Set-OfflineDomainJoin.ps1`** - Offline domain join of a remote machine via `djoin.exe` and WinRM
- **`Set-VMNestedVirtualization.ps1`** - Expose virtualization extensions to a Hyper-V VM
- **`Setup-DomainController.ps1`** - Outline for building a domain controller from scratch (not runnable as is)
- **`Update-WIndows.ps1`** - Ways to install Windows updates on Server Core
- **`dism.ps1`** - DISM / `Get-WindowsImage` command reference

### Utility

**`New-NuspecFromPsd.ps1`** - Generates a NuGet `.nuspec` file from a PowerShell module manifest (`.psd1`).
```powershell
.\Scripts\Utility\New-NuspecFromPsd.ps1 -ManifestPath .\MyModule\MyModule.psd1 -DestinationFolder .\out
```

## Authentication

### Azure DevOps

The Azure DevOps scripts call the REST API with a bearer token. When `-AccessToken` is omitted they acquire one via `Get-AzAccessToken` for the Azure DevOps resource, so sign in to Azure first:

```powershell
Connect-AzAccount
.\Scripts\AzureDevOps\Get-AdoProjectActivity.ps1 -Organization "https://dev.azure.com/YourOrg"
```

Or pass a token explicitly as a `SecureString`:

```powershell
$token = Read-Host -Prompt "Token" -AsSecureString
.\Scripts\AzureDevOps\Get-AdoProjectActivity.ps1 -Organization "https://dev.azure.com/YourOrg" -AccessToken $token
```

The identity needs read access to projects, repositories, pull requests and pushes.

### Microsoft 365

`reset_password_o365.ps1` calls `Connect-MsolService`, which prompts for credentials.

## Best Practices

- Always test scripts in a non-production environment first
- Use `-WhatIf` parameter where available to preview changes
- Store credentials securely using `Get-Credential` or Azure Key Vault
- Enable verbose output with `-Verbose` for troubleshooting
- Review script parameters and help documentation: `Get-Help ScriptName.ps1 -Full`

## Troubleshooting

### Authentication Issues

**Azure DevOps 401/403 errors:**
- Ensure you are signed in: `Connect-AzAccount`
- Verify the signed-in identity has access to the organisation
- If passing `-AccessToken`, verify the token hasn't expired

**MSOnline connection failures:**
- Reconnect: `Connect-MsolService`
- Check tenant permissions
- Verify MFA requirements

### Script Execution Issues

If scripts won't run:
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set to RemoteSigned (if allowed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Authors

See [AUTHORS.md](AUTHORS.md) for contributor information.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or suggestions:
- Open an [issue](https://github.com/jinyeow/PowerShellScripts/issues)

## Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Azure DevOps REST API](https://docs.microsoft.com/rest/api/azure/devops/)
