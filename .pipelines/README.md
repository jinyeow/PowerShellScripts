# PowerShell module publishing pipelines

CI/CD for publishing the PowerShell modules in this monorepo as NuGet packages, using
[PSResourceGet](https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/).

| Surface | Pipeline | Publishes to |
| --- | --- | --- |
| Azure DevOps | `.pipelines/.ado/publish-modules.azure-pipelines.yml` | Azure Artifacts feed |
| GitHub Actions | `.github/workflows/publish-modules.yml` | GitHub Packages (NuGet registry) |

Both pipelines share the scripts in `.pipelines/scripts/` and follow the same flow:

```
Detect changed modules -> Validate (PSSA + Pester + manifest) -> Publish -> Smoke test from feed
```

## Versioning

- `ModuleVersion` in `<ModuleName>/<ModuleName>.psd1` is the source of truth. Bump it
  manually as part of your change; a release build fails if that exact version already
  exists on the feed.
- **PR to `main`** publishes a prerelease: `<version>-pr<PR>b<runId>`, e.g.
  `1.2.0-pr12b000000034`. Every push to the PR produces a new, unique prerelease.
- **Merge to `main`** publishes the release: `1.2.0`.
- The prerelease label is ASCII-alphanumeric only (no dots): the manifest `Prerelease`
  field follows SemVer v1, which rejects `.`/`+`, and hyphens break older PowerShellGet
  clients. The run id is zero-padded so prerelease versions sort in build order.

Prerelease versions supersede nothing: `1.2.0` always outranks every `1.2.0-...`.

## Repository layout

A top-level directory is a module when it contains a manifest named after itself:

```
MyModule/
  MyModule.psd1        # manifest (flat layout, required)
  MyModule.psm1
  tests/               # Pester 5 tests (required to publish)
    MyModule.Tests.ps1
  ci.settings.json     # optional, see below
```

Only modules whose files changed in the push/PR are built and published.
`Scripts/`, `.pipelines/` and other non-module directories are ignored automatically
(no `<dir>/<dir>.psd1`).

### ci.settings.json

```json
{ "requiresAzureAuth": true }
```

Set this when a module's Pester tests need an authenticated Az / Microsoft Graph
context. Default is off; opted-in modules run their tests after `Connect-AzAccount`
(via service connection / OIDC) and `Connect-MgGraph`.

## Quality gates (block publishing)

1. **PSScriptAnalyzer** with `.vscode/PSScriptAnalyzerSettings.psd1`; any violation fails.
2. **Pester 5** tests from `<ModuleName>/tests/`, code coverage ≥ 10% (JaCoCo + NUnit
   results are uploaded to the run).
3. **Manifest validation**: `Test-ModuleManifest` plus the version-already-exists check.
4. **Post-publish smoke test**: a clean job installs the just-published version from the
   feed and imports it.

## Azure DevOps setup

1. Create (or reuse) an Azure Artifacts feed, e.g. `Codedapper.DevOps.PowerShell`.
2. Create a variable group named **`powershell-module-publishing`** with:
   - `ADO_ORGANIZATION` – org name from `https://dev.azure.com/<org>`
   - `ADO_PROJECT` – project hosting the feed (feed is assumed project-scoped)
   - `ARTIFACT_FEED_NAME` – e.g. `Codedapper.DevOps.PowerShell`
3. Give the pipeline identity (`<Project> Build Service (<org>)`) the **Contributor**
   role on the feed (Feed settings → Permissions).
4. Create a pipeline pointing at `.pipelines/.ado/publish-modules.azure-pipelines.yml`
   and permit it to use the variable group.
5. Only if a module sets `requiresAzureAuth`: pass an Azure service connection name via
   the `azureServiceConnection` pipeline parameter.

Auth uses the built-in `System.AccessToken`; no PAT is required.

> The older `ci.azure-pipelines.yml` / `deploy.azure-pipelines.yml` templates in
> `.pipelines/.ado/` (nuspec + nuget.exe based) are superseded by this pipeline.

## GitHub setup

Works out of the box: the workflow authenticates to GitHub Packages with the built-in
`GITHUB_TOKEN` (`packages: write`). Notes:

- PRs from forks receive a read-only token; validate runs, publish/smoke are skipped.
- Only if a module sets `requiresAzureAuth`: create an Entra app with federated
  credentials for this repo and add the `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and
  `AZURE_SUBSCRIPTION_ID` secrets ([azure/login OIDC](https://github.com/Azure/login#login-with-openid-connect-oidc-recommended)).
- GitHub Packages has no built-in retention for old prerelease versions; prune
  occasionally under the package's settings if the list gets noisy.

## Consuming the feeds

```powershell
# Azure Artifacts (PAT with Packaging read, or pipeline System.AccessToken)
$cred = Get-Credential   # username: anything, password: PAT
Register-PSResourceRepository -Name Codedapper -Trusted `
  -Uri 'https://pkgs.dev.azure.com/<org>/<project>/_packaging/<feed>/nuget/v3/index.json'
Install-PSResource -Name MyModule -Repository Codedapper -Credential $cred

# GitHub Packages (classic PAT with read:packages)
Register-PSResourceRepository -Name GitHub -Trusted `
  -Uri 'https://nuget.pkg.github.com/<owner>/index.json'
Install-PSResource -Name MyModule -Repository GitHub -Credential $cred

# Prerelease builds from a PR
Install-PSResource -Name MyModule -Version '1.2.0-pr12b000000034' -Prerelease -Repository ... -Credential $cred
```

## Scripts

All scripts are CI-agnostic and runnable locally with PowerShell 7:

| Script | Purpose |
| --- | --- |
| `Get-ChangedModule.ps1` | Diffs two refs and emits the changed modules as JSON |
| `Get-ModulePublishVersion.ps1` | Computes base/prerelease/full version for a build |
| `Invoke-ModuleAnalysis.ps1` | PSScriptAnalyzer gate |
| `Invoke-ModuleTests.ps1` | Pester 5 + coverage gate |
| `Publish-PSModule.ps1` | Stages, injects prerelease label, publishes via `Publish-PSResource` |
| `Test-PublishedPSModule.ps1` | Installs and imports a published version from the feed |

Local end-to-end dry run against a folder feed:

```powershell
./.pipelines/scripts/Publish-PSModule.ps1 -ModulePath ./MyModule `
  -RepositoryUri "file:///tmp/localfeed" -PrereleaseLabel 'pr1b000000001'
./.pipelines/scripts/Test-PublishedPSModule.ps1 -ModuleName MyModule `
  -Version '1.2.0-pr1b000000001' -RepositoryUri "file:///tmp/localfeed" -MaxAttempts 1
```
