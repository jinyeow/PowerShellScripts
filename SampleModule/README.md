# SampleModule

A minimal PowerShell module used to validate the Azure DevOps build/test/publish
pipeline end to end. It has no external dependencies so it can be built, tested
and packed without Azure or Microsoft Graph authentication.

## Layout

```
SampleModule/
├── src/
│   ├── SampleModule.psd1        # module manifest (ModuleVersion 0.1.0)
│   ├── SampleModule.psm1        # dot-sources and exports public functions
│   └── Public/
│       └── Get-SampleGreeting.ps1
└── tests/
    └── Get-SampleGreeting.Tests.ps1   # Pester 5 tests
```

This matches the layout the pipeline expects: `<ModuleName>/src/<ModuleName>.psd1`
for packing and `<ModuleName>/tests` for Pester.

## Run locally

```powershell
# Static analysis
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ../.vscode/PSScriptAnalyzerSettings.psd1

# Tests
Invoke-Pester -Path ./tests

# Use it
Import-Module ./src/SampleModule.psd1 -Force
Get-SampleGreeting -Name 'Ada'   # -> 'Hello, Ada!'
```

## Versioning in CI

- Builds from `main` publish the plain `ModuleVersion` (e.g. `0.1.0`).
- Builds from any other branch get a prerelease label stamped onto the manifest,
  producing `0.1.0-build<zero-padded BuildId>` (e.g. `0.1.0-build0000000042`).
