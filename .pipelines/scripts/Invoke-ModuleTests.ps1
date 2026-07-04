#Requires -Version 7.0

<#
    .SYNOPSIS
    Runs a module's Pester tests with code coverage and enforces a coverage threshold.

    .DESCRIPTION
    Expects the flat monorepo layout:
        <ModuleName>/<ModuleName>.psd1
        <ModuleName>/tests/*.Tests.ps1

    Produces NUnit test results and JaCoCo coverage output for CI upload.

    .EXAMPLE
    ./Invoke-ModuleTests.ps1 -ModulePath ./MyModule -TestResultsPath ./TestResults.xml
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string] $ModulePath,

    [Parameter(Mandatory = $false)]
    [string] $TestResultsPath = (Join-Path $ModulePath 'TestResults.xml'),

    [Parameter(Mandatory = $false)]
    [string] $CoverageOutputPath = (Join-Path $ModulePath 'coverage.xml'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int] $CoverageThreshold = 10
)

$ErrorActionPreference = 'Stop'

$moduleName = Split-Path -Path (Resolve-Path $ModulePath) -Leaf
$manifestPath = Join-Path $ModulePath "$moduleName.psd1"
if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
    throw "Module manifest '$manifestPath' not found. Expected flat layout <ModuleName>/<ModuleName>.psd1."
}

Write-Host "##[section]Validating module manifest '$manifestPath'"
$null = Test-ModuleManifest -Path $manifestPath

$testsPath = Join-Path $ModulePath 'tests'
if (-not (Test-Path -Path $testsPath -PathType Container)) {
    throw "No 'tests' directory found in '$ModulePath'. Pester tests are required before a module can be published."
}

$requiredPesterVersion = [version] '5.0.0'
$pester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge $requiredPesterVersion } |
    Select-Object -First 1
if (-not $pester) {
    Write-Host 'Installing Pester...'
    Install-PSResource -Name Pester -TrustRepository -Scope CurrentUser
}
Import-Module -Name Pester -MinimumVersion $requiredPesterVersion -Force

# Cover module source files only; test code itself is excluded.
$testsFullPath = (Resolve-Path $testsPath).Path
$coverageFiles = @(
    Get-ChildItem -Path $ModulePath -Recurse -Include '*.ps1', '*.psm1' -File |
        Where-Object { -not $_.FullName.StartsWith($testsFullPath) } |
        Select-Object -ExpandProperty FullName
)

$config = New-PesterConfiguration
$config.Run.Path = $testsPath
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $TestResultsPath

if ($coverageFiles.Count -gt 0) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = $CoverageOutputPath
    $config.CodeCoverage.Path = $coverageFiles
    $config.CodeCoverage.CoveragePercentTarget = $CoverageThreshold
} else {
    Write-Warning "No .ps1/.psm1 source files found outside 'tests'; code coverage is skipped."
}

Write-Host "##[section]Running Pester tests for '$moduleName'"
$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) Pester test(s) failed for module '$moduleName'."
}
if ($result.TotalCount -eq 0) {
    throw "No Pester tests were discovered in '$testsPath'."
}

if ($config.CodeCoverage.Enabled.Value) {
    $coveragePercent = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
    Write-Host "Code coverage: $coveragePercent% (threshold: $CoverageThreshold%)"
    if ($coveragePercent -lt $CoverageThreshold) {
        throw "Code coverage $coveragePercent% is below the required threshold of $CoverageThreshold%."
    }
}

Write-Host "Pester tests passed for '$moduleName' ($($result.PassedCount) passed)."
