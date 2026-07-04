#Requires -Version 7.0

<#
    .SYNOPSIS
    Computes the version a module will be published as, so the publish and smoke-test
    jobs derive the identical version independently.

    .DESCRIPTION
    The base version always comes from ModuleVersion in <ModuleName>/<ModuleName>.psd1.

    When -PullRequestNumber is provided (prerelease build) the label is
    'pr<PR>b<9-digit run id>', e.g. 1.2.0-pr12b000000034. The label is deliberately
    ASCII-alphanumeric only: the manifest Prerelease field follows SemVer v1, which
    forbids '.' and '+', and hyphens break older PowerShellGet consumers. Zero-padding
    keeps lexical (SemVer v1) ordering consistent with build order.

    .OUTPUTS
    Single-line compressed JSON: {"baseVersion":"1.2.0","prereleaseLabel":"...","fullVersion":"..."}
    prereleaseLabel is an empty string for release builds.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string] $ModulePath,

    # Empty for release builds from main.
    [Parameter(Mandatory = $false)]
    [string] $PullRequestNumber = '',

    # Unique, increasing CI run identifier (Build.BuildId / github.run_id).
    [Parameter(Mandatory = $false)]
    [string] $BuildId = ''
)

$ErrorActionPreference = 'Stop'

$moduleName = Split-Path -Path (Resolve-Path $ModulePath) -Leaf
$manifest = Import-PowerShellDataFile -Path (Join-Path $ModulePath "$moduleName.psd1")
$baseVersion = [string] $manifest.ModuleVersion

$prereleaseLabel = ''
if ($PullRequestNumber) {
    if ($PullRequestNumber -notmatch '^\d+$') {
        throw "Pull request number '$PullRequestNumber' is not numeric; cannot build a prerelease label."
    }
    if ($BuildId -notmatch '^\d+$') {
        throw "Build id '$BuildId' is not numeric; cannot build a prerelease label."
    }
    if ($baseVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "ModuleVersion '$baseVersion' must be a 3-part Major.Minor.Build version to carry a prerelease label."
    }
    $prereleaseLabel = 'pr{0}b{1:d9}' -f $PullRequestNumber, [long] $BuildId
}

$fullVersion = if ($prereleaseLabel) { "$baseVersion-$prereleaseLabel" } else { $baseVersion }

ConvertTo-Json -InputObject ([ordered]@{
    baseVersion     = $baseVersion
    prereleaseLabel = $prereleaseLabel
    fullVersion     = $fullVersion
}) -Compress
