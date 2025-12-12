# Contributing to PowerShellScripts

Thank you for considering contributing to this project! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

Before creating an issue:
1. Search existing issues to avoid duplicates
2. Use the issue template if available
3. Include:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - PowerShell version and OS
   - Error messages or screenshots

### Suggesting Enhancements

Enhancement suggestions are welcome:
- Explain the use case and benefits
- Provide examples of how it would work
- Consider backward compatibility

### Pull Requests

1. **Fork the repository** and create a feature branch:
   ```powershell
   git checkout -b feature/your-feature-name
   ```

2. **Follow coding standards**:
   - Use approved PowerShell verbs (`Get-Verb` for reference)
   - Follow [PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/)
   - Use PascalCase for function names
   - Use camelCase for parameters
   - Include comment-based help for all functions

3. **Write clear commit messages**:
   ```
   Add Get-AdoProjectMember function

   - Retrieves project members from Azure DevOps
   - Supports filtering by group
   - Includes error handling for API failures
   ```

4. **Test your changes**:
   - Test on PowerShell 5.1 and PowerShell 7+ where possible
   - Verify backward compatibility
   - Include `Pester` tests for new functions

5. **Update documentation**:
   - Add comment-based help to functions
   - Update README.md if adding new features
   - Update CHANGELOG.md

6. **Submit the pull request**:
   - Reference any related issues
   - Describe what changed and why
   - Note any breaking changes

## Coding Standards

### Function Structure

```powershell
<#
.SYNOPSIS
Brief description of what the function does.

.DESCRIPTION
Detailed description of the function's behavior.

.PARAMETER ParameterName
Description of the parameter.

.EXAMPLE
Example-Function -ParameterName "Value"
Description of what this example does.

.NOTES
Additional information, author, version.
#>
function Verb-Noun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ParameterName,

        [Parameter()]
        [switch]$OptionalSwitch
    )

    begin {
        # Initialization code
    }

    process {
        # Main logic
        try {
            # Code that might fail
        }
        catch {
            Write-Error "Error message: $_"
            throw
        }
    }

    end {
        # Cleanup code
    }
}
```

### Best Practices

**Error Handling:**
```powershell
try {
    $result = Get-Something -ErrorAction Stop
}
catch {
    Write-Error "Failed to get something: $_"
    return
}
```

**Parameter Validation:**
```powershell
[Parameter(Mandatory)]
[ValidateNotNullOrEmpty()]
[ValidatePattern('^https://')]
[string]$Url
```

**Output:**
- Return objects, not formatted text
- Use `Write-Verbose` for detailed logging
- Use `Write-Warning` for non-fatal issues
- Use `Write-Error` for failures

## Testing

Use Pester for unit tests:

```powershell
Describe "Get-AdoProjectMember" {
    It "Returns member list" {
        $result = Get-AdoProjectMember -Project "TestProject"
        $result | Should -Not -BeNullOrEmpty
        $result[0].displayName | Should -Not -BeNullOrEmpty
    }

    It "Throws error for invalid project" {
        { Get-AdoProjectMember -Project "InvalidProject" } | Should -Throw
    }
}
```

Run tests:
```powershell
Invoke-Pester -Path .\Tests\
```

## Module Development

When creating or modifying modules:

1. **Manifest files** (`.psd1`) should include:
   - Version number (SemVer format)
   - Author information
   - Required modules/PowerShell version
   - Exported functions

2. **Module structure**:
   ```
   ModuleName/
   ├── ModuleName.psd1      # Module manifest
   ├── ModuleName.psm1      # Module file
   ├── Public/              # Exported functions
   ├── Private/             # Internal functions
   └── Tests/               # Pester tests
   ```

3. **Export only public functions**:
   ```powershell
   Export-ModuleMember -Function Get-*, Set-*, Remove-*
   ```

## Documentation

### Comment-Based Help

All functions must include:
- `.SYNOPSIS` - One-line description
- `.DESCRIPTION` - Detailed explanation
- `.PARAMETER` - For each parameter
- `.EXAMPLE` - At least one usage example
- `.NOTES` - Optional additional information

### README Updates

When adding new scripts or features:
- Add to the "Key Scripts" section
- Include usage examples
- Update prerequisites if needed

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR** - Breaking changes
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (backward compatible)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Open an issue with the `question` label for clarification on contribution guidelines.
