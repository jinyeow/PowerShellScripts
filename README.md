# PowerShellScripts

A personal collection of PowerShell scripts and modules for automation, administration, and DevOps tasks.

## Overview

This repository contains PowerShell scripts and modules developed for various administrative and automation tasks, including:

- Azure DevOps administration and security management
- Microsoft 365/Office 365 user management
- Network utilities and diagnostics
- Server administration (Windows Server 2016+)
- Identity and access management

## Prerequisites

- **PowerShell Version**: PowerShell 5.1 or PowerShell 7+ (preferred)
- **Required Modules**:
  - `Az` (Azure PowerShell)
  - `Microsoft.Graph` (Microsoft Graph API)
  - Azure CLI (`az`) installed and configured
  
Install required modules:
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Install-Module -Name Microsoft.Graph -Scope CurrentUser
```

## Repository Structure

```
PowerShellScripts/
├── 
├── Modules/              # Custom PowerShell modules
│   ├── Common/           # General scripts
│   ├── EntraID/          # Permission management module
│   └── Permissions/      # General scripts
├── Scripts/              # Standalone utility scripts
│   ├── General/          # General scripts
│   ├── Office365/        # Office365 specific scripts
│   └── Server 2016/      # Server 2016-specific scripts
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

## Quick Start

### Using Modules

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/jinyeow/PowerShellScripts.git
   cd PowerShellScripts
   ```

2. **Import a module**:
   ```powershell
   Import-Module .\Modules\Hollard.Permissions\Hollard.Permissions.psd1
   ```

3. **List available commands**:
   ```powershell
   Get-Command -Module Hollard.Permissions
   ```

### Using Standalone Scripts

Run scripts directly from their location:

```powershell
# Network scanning
.\network_scan.ps1 -Network "192.168.1.0/24"

# Reset Office 365 password
.\reset_password_o365.ps1 -UserPrincipalName "user@domain.com"
```

## Key Scripts

### Network Utilities

**`network_scan.ps1`** - Network scanning and host discovery
```powershell
.\network_scan.ps1 -Network "192.168.1.0/24" -Ports 80,443,3389
```

### Microsoft 365 Administration

**`reset_password_o365.ps1`** - Reset user passwords in Office 365
```powershell
.\reset_password_o365.ps1 -UserPrincipalName "user@contoso.com" -NewPassword "SecurePass123!"
```

## Authentication

### Azure DevOps

Scripts interacting with Azure DevOps require authentication via Personal Access Token (PAT):

```powershell
# Set PAT as environment variable
$env:AZURE_DEVOPS_EXT_PAT = "your-pat-token"

# Or authenticate via Azure CLI
az devops login --organization https://dev.azure.com/YourOrg
```

Create a PAT at: `https://dev.azure.com/{organization}/_usersSettings/tokens`

Required scopes:
- Identity (read)
- Security (manage)
- Work Items (read/write)

### Microsoft Graph

Authenticate with Microsoft Graph:

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All"
```

## Common Tasks

### Managing Azure DevOps Permissions

```powershell
# Get project group members
Get-AdoProjectGroupMember -Organization "https://dev.azure.com/YourOrg" -Project "ProjectName" -Group "Contributors"

# Add user to group
Add-AdoGroupMember -Organization "https://dev.azure.com/YourOrg" -GroupDescriptor "vssgp.xxx" -MemberDescriptor "aad.yyy"

# Remove user from group
Remove-AdoGroupMember -Organization "https://dev.azure.com/YourOrg" -GroupDescriptor "vssgp.xxx" -MemberDescriptor "aad.yyy"
```

## Best Practices

- Always test scripts in a non-production environment first
- Use `-WhatIf` parameter where available to preview changes
- Store credentials securely using `Get-Credential` or Azure Key Vault
- Enable verbose output with `-Verbose` for troubleshooting
- Review script parameters and help documentation: `Get-Help ScriptName.ps1 -Full`

## Troubleshooting

### Authentication Issues

**Azure DevOps "requires user authentication" error:**
- Ensure PAT is set: `$env:AZURE_DEVOPS_EXT_PAT = "your-pat"`
- Verify PAT hasn't expired
- Check PAT has required scopes

**Microsoft Graph connection failures:**
- Reconnect: `Connect-MgGraph -Scopes "User.ReadWrite.All"`
- Check tenant permissions
- Verify MFA requirements

### Module Loading Issues

If modules don't load:
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set to RemoteSigned (if allowed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Import with full path
Import-Module "C:\Full\Path\To\Module.psd1" -Force
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Authors

See [AUTHORS.md](AUTHORS.md) for contributor information.

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or suggestions:
- Open an [issue](https://github.com/jinyeow/PowerShellScripts/issues)
- Review existing [documentation](https://github.com/jinyeow/PowerShellScripts/wiki)

## Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [Microsoft Graph PowerShell SDK](https://docs.microsoft.com/graph/powershell/get-started)
- [Azure DevOps CLI](https://docs.microsoft.com/azure/devops/cli/)