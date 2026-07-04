#Requires -Version 7.0

<#
    .SYNOPSIS
    Runs PSScriptAnalyzer over a module directory and fails on any finding.

    .EXAMPLE
    ./Invoke-ModuleAnalysis.ps1 -ModulePath ./MyModule
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string] $ModulePath,

    [Parameter(Mandatory = $false)]
    [string] $SettingsPath = (Join-Path (& git rev-parse --show-toplevel) '.vscode/PSScriptAnalyzerSettings.psd1')
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host 'Installing PSScriptAnalyzer...'
    Install-PSResource -Name PSScriptAnalyzer -TrustRepository -Scope CurrentUser
}
Import-Module -Name PSScriptAnalyzer

$params = @{
    Path              = $ModulePath
    Recurse           = $true
    ReportSummary     = $true
    IncludeSuppressed = $true
}
if (Test-Path -Path $SettingsPath -PathType Leaf) {
    $params.Settings = $SettingsPath
} else {
    Write-Warning "PSScriptAnalyzer settings file '$SettingsPath' not found; using default rules."
}

$results = Invoke-ScriptAnalyzer @params
$violations = @($results | Where-Object { -not $_.IsSuppressed })

if ($violations.Count -gt 0) {
    $violations | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String | Write-Host
    throw "PSScriptAnalyzer found $($violations.Count) violation(s) in '$ModulePath'."
}

Write-Host "PSScriptAnalyzer passed for '$ModulePath'."
