# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- README.md with comprehensive documentation
- CONTRIBUTING.md with contribution guidelines
- CHANGELOG.md for version tracking
- AUTHORS.md for contributor recognition
- `Get-AdoProjectActivity.ps1` - Ranks Azure DevOps projects by how disruptive a branch-policy rollout would be, least disruptive first
- `Get-AdoRepositoryActivity.ps1` - Reports per-repository push activity and main pusher(s) for one Azure DevOps project
- `Scripts/AzureDevOps/Private/Invoke-AdoRestMethodWithRetry.ps1` - Shared REST helper vendored into both Azure DevOps scripts
- `Scripts/AzureDevOps/Private/Get-AdoBranchPolicyEligibleRepository.ps1` - Shared repository-eligibility helper vendored in for `Get-AdoProjectActivity.ps1`
- `Scripts/AzureDevOps/Private/ConvertTo-AdoUtcDateTime.ps1` - Shared date-conversion helper deduped out of both Azure DevOps scripts
- `.github/workflows/lint.yml` - PSScriptAnalyzer CI workflow

### Fixed
- `Scripts/Server 2016/Set-NanoServerConfiguration.ps1` - Removed a hardcoded plaintext password; now prompts for it via `Read-Host -AsSecureString`
- `Scripts/Office365/reset_password_o365.ps1` - Fixed a missing line-continuation backtick that kept `-WhatIf` from binding to the actual call, and assigned the previously-unset `$password` variable

## [0.1.0] - Initial Release

### Added
- `network_scan.ps1` - Network scanning utility
- `reset_password_o365.ps1` - Office 365 password reset script
- Server 2016 administration scripts
- MIT License
- Basic repository structure

[Unreleased]: https://github.com/jinyeow/PowerShellScripts/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jinyeow/PowerShellScripts/releases/tag/v0.1.0
