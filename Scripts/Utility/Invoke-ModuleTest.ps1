#Requires -Version 7.0

<#
    .SYNOPSIS
    Runs a module's Pester tests with code coverage and emits NUnit + JaCoCo output.

    .DESCRIPTION
    Shared by the CI pipeline so the default (no-auth) and Azure-authenticated
    test paths run identical test logic. Ensures Pester 5+ is available, then
    invokes the tests under <ModulePath>/tests with coverage over
    <ModulePath>/src.

    .PARAMETER ModulePath
    Path to the module directory that contains the src/ and tests/ folders.

    .PARAMETER TestResultsPath
    File path for the NUnit test-results XML.

    .PARAMETER CoverageThreshold
    Minimum code-coverage percentage target. Defaults to 10.

    .EXAMPLE
    ./Invoke-ModuleTest.ps1 -ModulePath ./SampleModule -TestResultsPath ./TestResults.xml
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string] $ModulePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $TestResultsPath,

    [Parameter(Mandatory = $false)]
    [int] $CoverageThreshold = 10
)

$ErrorActionPreference = 'Stop'

$requiredVersion = '5.0.0'
$pesterModule = Get-Module -ListAvailable -Name Pester |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1
if (-not $pesterModule -or $pesterModule.Version -lt $requiredVersion) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}
Import-Module -Name Pester -MinimumVersion $requiredVersion -Force

$config = New-PesterConfiguration
$config.Run.Path = Join-Path -Path $ModulePath -ChildPath 'tests'
$config.Run.PassThru = $true
# Return the result object instead of exiting inline, so both test failures and
# coverage can be enforced as gates below.
$config.Run.Exit = $false

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = Join-Path -Path $ModulePath -ChildPath 'coverage.xml'
$config.CodeCoverage.Path = Join-Path -Path $ModulePath -ChildPath 'src'
$config.CodeCoverage.CoveragePercentTarget = $CoverageThreshold

$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $TestResultsPath

$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) test(s) failed."
}

# CoveragePercentTarget only reports; enforce it here so the threshold is a real
# gate rather than a display value.
$coveragePercent = [double] $result.CodeCoverage.CoveragePercent
if ($coveragePercent -lt $CoverageThreshold) {
    throw ('Code coverage {0:N2}% is below the required threshold of {1}%.' -f $coveragePercent, $CoverageThreshold)
}
