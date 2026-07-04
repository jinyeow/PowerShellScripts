#Requires -Version 7.0

<#
    .SYNOPSIS
    Post-publish smoke test: installs a just-published module version from the feed and
    imports it, proving the package is actually consumable.

    .EXAMPLE
    ./Test-PublishedPSModule.ps1 -ModuleName MyModule -Version '1.2.0-pr12b000034' `
        -RepositoryUri 'https://pkgs.dev.azure.com/org/project/_packaging/feed/nuget/v3/index.json' `
        -Token $env:SYSTEM_ACCESSTOKEN
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $ModuleName,

    # Full version, including any prerelease suffix (e.g. 1.2.0-pr12b000034).
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $RepositoryUri,

    [Parameter(Mandatory = $false)]
    [string] $Token,

    [Parameter(Mandatory = $false)]
    [string] $Username = 'pipeline',

    # Feeds can take a moment to index a freshly pushed package.
    [Parameter(Mandatory = $false)]
    [int] $MaxAttempts = 5,

    [Parameter(Mandatory = $false)]
    [int] $RetryDelaySeconds = 15
)

$ErrorActionPreference = 'Stop'

$isRemoteFeed = $RepositoryUri -match '^https?://'
if ($isRemoteFeed -and -not $Token) {
    throw "A -Token is required when installing from a remote feed ($RepositoryUri)."
}

if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet)) {
    Install-PSResource -Name Microsoft.PowerShell.PSResourceGet -TrustRepository -Scope CurrentUser
}
Import-Module -Name Microsoft.PowerShell.PSResourceGet

$isPrerelease = $Version.Contains('-')
$repoName = "smoketest-$ModuleName"

try {
    Register-PSResourceRepository -Name $repoName -Uri $RepositoryUri -Trusted -Force

    $installParams = @{
        Name            = $ModuleName
        Version         = $Version
        Repository      = $repoName
        TrustRepository = $true
        Scope           = 'CurrentUser'
        Prerelease      = $isPrerelease
        Reinstall       = $true
    }
    if ($isRemoteFeed) {
        $securePassword = ConvertTo-SecureString -String $Token -AsPlainText -Force
        $installParams.Credential = [pscredential]::new($Username, $securePassword)
    }

    $installed = $false
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Write-Host "##[section]Installing $ModuleName $Version from feed (attempt $attempt/$MaxAttempts)"
            Install-PSResource @installParams
            $installed = $true
            break
        } catch {
            if ($attempt -eq $MaxAttempts) { throw }
            Write-Warning "Install failed ($($_.Exception.Message)); retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    if (-not $installed) {
        throw "Failed to install $ModuleName $Version from '$RepositoryUri'."
    }

    Write-Host "##[section]Importing $ModuleName"
    Import-Module -Name $ModuleName -Force
    $module = Get-Module -Name $ModuleName
    if (-not $module) {
        throw "Module '$ModuleName' failed to import after installation."
    }

    $importedVersion = $module.Version.ToString()
    $prereleaseTag = $module.PrivateData.PSData.Prerelease
    $importedFullVersion = if ($prereleaseTag) { "$importedVersion-$prereleaseTag" } else { $importedVersion }
    if ($importedFullVersion -ne $Version) {
        throw "Imported version '$importedFullVersion' does not match the expected '$Version'."
    }

    Write-Host "Smoke test passed: $ModuleName $importedFullVersion imported successfully."
    Write-Host "Exported commands: $($module.ExportedCommands.Keys -join ', ')"
} finally {
    Get-PSResourceRepository -Name $repoName -ErrorAction SilentlyContinue |
        ForEach-Object { Unregister-PSResourceRepository -Name $repoName }
}
