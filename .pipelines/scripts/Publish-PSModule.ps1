#Requires -Version 7.0

<#
    .SYNOPSIS
    Publishes a PowerShell module to a NuGet-based feed (Azure Artifacts, GitHub Packages,
    or a local/file-share repository) using PSResourceGet.

    .DESCRIPTION
    Expects the flat monorepo layout <ModuleName>/<ModuleName>.psd1. The module directory is
    staged to a temp location (excluding tests/ and CI files) so the working tree is never
    modified.

    When -PrereleaseLabel is supplied, it is injected into PrivateData.PSData.Prerelease of
    the staged manifest, producing a version like 1.2.0-pr12b000034. The label must be ASCII
    alphanumeric only: the module-manifest Prerelease field follows SemVer v1 and rejects
    dots and pluses, and hyphens break older PowerShellGet consumers.

    Without -PrereleaseLabel a release version is published; the script fails if that exact
    version already exists on the feed (bump ModuleVersion in the psd1 first).

    .OUTPUTS
    Writes the published version as the final output line, and exposes it to CI:
    Azure DevOps output variable and GITHUB_OUTPUT entry named 'publishedVersion'.

    .EXAMPLE
    ./Publish-PSModule.ps1 -ModulePath ./MyModule `
        -RepositoryUri 'https://pkgs.dev.azure.com/org/project/_packaging/feed/nuget/v3/index.json' `
        -Token $env:SYSTEM_ACCESSTOKEN -PrereleaseLabel 'pr12b000034'
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string] $ModulePath,

    [Parameter(Mandatory = $true)]
    [string] $RepositoryUri,

    # PAT / System.AccessToken / GITHUB_TOKEN. Required for http(s) feeds.
    [Parameter(Mandatory = $false)]
    [string] $Token,

    [Parameter(Mandatory = $false)]
    [string] $Username = 'pipeline',

    # Some feeds want a real API key; Azure Artifacts ignores it (auth is the credential),
    # GitHub Packages uses the token. Defaults to -Token.
    [Parameter(Mandatory = $false)]
    [string] $ApiKey,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9A-Za-z]+$')]
    [string] $PrereleaseLabel,

    # Files/directories inside the module folder that must not ship in the package.
    [Parameter(Mandatory = $false)]
    [string[]] $ExcludePaths = @('tests', 'ci.settings.json', 'TestResults.xml', 'coverage.xml')
)

$ErrorActionPreference = 'Stop'

$isRemoteFeed = $RepositoryUri -match '^https?://'
if ($isRemoteFeed -and -not $Token) {
    throw "A -Token is required when publishing to a remote feed ($RepositoryUri)."
}

if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet)) {
    Write-Host 'Installing Microsoft.PowerShell.PSResourceGet...'
    Install-PSResource -Name Microsoft.PowerShell.PSResourceGet -TrustRepository -Scope CurrentUser
}
Import-Module -Name Microsoft.PowerShell.PSResourceGet

$moduleName = Split-Path -Path (Resolve-Path $ModulePath) -Leaf
$manifestPath = Join-Path $ModulePath "$moduleName.psd1"
if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
    throw "Module manifest '$manifestPath' not found. Expected flat layout <ModuleName>/<ModuleName>.psd1."
}

Write-Host "##[section]Validating manifest"
$moduleInfo = Test-ModuleManifest -Path $manifestPath
$baseVersion = $moduleInfo.Version.ToString()
if ($baseVersion -notmatch '^\d+\.\d+\.\d+$' -and $PrereleaseLabel) {
    throw "ModuleVersion '$baseVersion' must be a 3-part Major.Minor.Build version to carry a prerelease label."
}

$fullVersion = if ($PrereleaseLabel) { "$baseVersion-$PrereleaseLabel" } else { $baseVersion }
Write-Host "Publishing $moduleName $fullVersion to $RepositoryUri"

# Stage the module so the working tree stays untouched.
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) "psmodule-publish-$([guid]::NewGuid().ToString('N'))"
$stagingPath = Join-Path $stagingRoot $moduleName
New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $ModulePath '*') -Destination $stagingPath -Recurse -Force
foreach ($exclude in $ExcludePaths) {
    $excludePath = Join-Path $stagingPath $exclude
    if (Test-Path -Path $excludePath) {
        Remove-Item -Path $excludePath -Recurse -Force
    }
}

$repoName = "publish-$moduleName"
try {
    if ($PrereleaseLabel) {
        $stagedManifest = Join-Path $stagingPath "$moduleName.psd1"
        $content = Get-Content -Path $stagedManifest -Raw

        if ($content -match "(?m)^\s*Prerelease\s*=") {
            $content = $content -replace "(?m)^(\s*)Prerelease\s*=\s*(['""])[^'""]*\2", "`$1Prerelease = '$PrereleaseLabel'"
        } elseif ($content -match '(?m)^(\s*)PSData\s*=\s*@\{') {
            $indent = $Matches[1]
            $content = $content -replace '(?m)^(\s*)(PSData\s*=\s*@\{)', "`$1`$2`n`$1    Prerelease = '$PrereleaseLabel'"
        } else {
            throw "Cannot inject prerelease label: manifest '$stagedManifest' has no PrivateData.PSData block. Add one (New-ModuleManifest generates it by default)."
        }
        Set-Content -Path $stagedManifest -Value $content -NoNewline

        $staged = Test-ModuleManifest -Path $stagedManifest
        $stagedPrerelease = $staged.PrivateData.PSData.Prerelease
        if ($stagedPrerelease -ne $PrereleaseLabel) {
            throw "Prerelease injection failed: manifest reports '$stagedPrerelease', expected '$PrereleaseLabel'."
        }
    }

    Write-Host "##[section]Registering repository '$repoName'"
    Register-PSResourceRepository -Name $repoName -Uri $RepositoryUri -Trusted -Force

    $credential = $null
    if ($isRemoteFeed) {
        $securePassword = ConvertTo-SecureString -String $Token -AsPlainText -Force
        $credential = [pscredential]::new($Username, $securePassword)
    }

    Write-Host "##[section]Checking the feed for an existing $moduleName $fullVersion"
    $findParams = @{
        Name        = $moduleName
        Version     = $fullVersion
        Repository  = $repoName
        ErrorAction = 'SilentlyContinue'
    }
    if ($PrereleaseLabel) { $findParams.Prerelease = $true }
    if ($credential) { $findParams.Credential = $credential }
    $existing = Find-PSResource @findParams
    if ($existing) {
        throw "Version $fullVersion of '$moduleName' already exists on the feed. Bump ModuleVersion in $moduleName.psd1."
    }

    Write-Host "##[section]Publishing"
    $publishParams = @{
        Path       = $stagingPath
        Repository = $repoName
    }
    if ($isRemoteFeed) {
        $publishParams.Credential = $credential
        $publishParams.ApiKey = if ($ApiKey) { $ApiKey } else { $Token }
    }
    Publish-PSResource @publishParams

    Write-Host "Published $moduleName $fullVersion."
} finally {
    Get-PSResourceRepository -Name $repoName -ErrorAction SilentlyContinue |
        ForEach-Object { Unregister-PSResourceRepository -Name $repoName }
    Remove-Item -Path $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($env:TF_BUILD) {
    Write-Host "##vso[task.setvariable variable=publishedVersion;isOutput=true]$fullVersion"
}
if ($env:GITHUB_OUTPUT) {
    "publishedVersion=$fullVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}
Write-Output $fullVersion
