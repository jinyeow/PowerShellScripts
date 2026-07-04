#Requires -Version 7.0

<#
    .SYNOPSIS
    Detects which PowerShell modules in this monorepo changed between two git refs.

    .DESCRIPTION
    A top-level directory is treated as a module when it contains a manifest named
    after the directory (flat layout: <ModuleName>/<ModuleName>.psd1).

    Each module may carry an optional ci.settings.json next to its manifest:
        { "requiresAzureAuth": true }
    which is surfaced in the output so pipelines can decide whether the module's
    Pester tests need an authenticated Azure/Graph context.

    .OUTPUTS
    A single-line compressed JSON array (always an array, possibly empty) of:
        [{ "moduleName": "Foo", "requiresAzureAuth": false }, ...]

    .EXAMPLE
    ./Get-ChangedModule.ps1 -BaseRef origin/main
#>
[CmdletBinding()]
param (
    # Ref to diff against, e.g. 'origin/main' for PR builds or 'HEAD^' on main.
    [Parameter(Mandatory = $true)]
    [string] $BaseRef,

    [Parameter(Mandatory = $false)]
    [string] $HeadRef = 'HEAD',

    [Parameter(Mandatory = $false)]
    [string] $RepositoryRoot = (& git rev-parse --show-toplevel)
)

$ErrorActionPreference = 'Stop'

& git -C $RepositoryRoot rev-parse --verify --quiet "$BaseRef^{commit}" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Base ref '$BaseRef' cannot be resolved. Ensure the pipeline checks out enough history (fetchDepth: 0)."
}

# Triple-dot: diff against the merge base, so a stale PR branch only reports its own changes.
$changedFiles = & git -C $RepositoryRoot diff --name-only "$BaseRef...$HeadRef"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Merge-base diff failed; falling back to a direct diff of '$BaseRef' and '$HeadRef'."
    $changedFiles = & git -C $RepositoryRoot diff --name-only "$BaseRef" "$HeadRef"
    if ($LASTEXITCODE -ne 0) {
        throw "git diff between '$BaseRef' and '$HeadRef' failed."
    }
}

$topLevelDirs = $changedFiles |
    Where-Object { $_ -match '/' } |
    ForEach-Object { ($_ -split '/')[0] } |
    Sort-Object -Unique

$modules = foreach ($dir in $topLevelDirs) {
    $manifestPath = Join-Path $RepositoryRoot $dir "$dir.psd1"
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        continue
    }

    $requiresAzureAuth = $false
    $settingsPath = Join-Path $RepositoryRoot $dir 'ci.settings.json'
    if (Test-Path -Path $settingsPath -PathType Leaf) {
        $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        $requiresAzureAuth = [bool] $settings.requiresAzureAuth
    }

    [pscustomobject]@{
        moduleName        = $dir
        requiresAzureAuth = $requiresAzureAuth
    }
}

$modules = @($modules)
Write-Verbose "Changed modules: $($modules.moduleName -join ', ')"

# -InputObject (not pipeline) keeps the array intact, so one module still serializes as [{...}]
ConvertTo-Json -InputObject $modules -Compress
