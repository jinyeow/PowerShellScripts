<#
    .SYNOPSIS
    Lists a project's non-disabled Git repositories, the eligibility filter shared
    by every branch-policy function that needs to enumerate repositories.

    .DESCRIPTION
    Wraps the Repositories - List API (`_apis/git/repositories`) and excludes any
    repository with `isDisabled` set, so callers never have to duplicate that
    filter inline. Any failure from the underlying REST call (including retries
    exhausted in Invoke-AdoRestMethodWithRetry) propagates to the caller rather
    than being swallowed here, since callers report a failed listing differently
    (e.g. a single project-level row vs. failing the whole run).

    .PARAMETER Organization
    Azure DevOps organisation URL, e.g. https://dev.azure.com/{org}.

    .PARAMETER Project
    The Azure DevOps project to list repositories for.

    .PARAMETER Headers
    Request headers (bearer token) for the Azure DevOps REST API.

    .OUTPUTS
    [object[]] The raw repository objects (id, name, defaultBranch, isDisabled, ...)
    for every non-disabled repository in the project.
#>
function Get-AdoBranchPolicyEligibleRepository {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers
    )

    $reposUri = "$Organization/$Project/_apis/git/repositories?api-version=7.1"
    $reposResponse = Invoke-AdoRestMethodWithRetry -Parameters @{
        Uri = $reposUri
        Method = 'Get'
        Headers = $Headers
    }
    return @($reposResponse.value) | Where-Object { $_ -and -not $_.isDisabled }
}
