#Requires -Version 7.0
#Requires -Modules Az.Accounts

<#
    .SYNOPSIS
    Ranks every project in an Azure DevOps organisation by how much the project-wide
    branch-policy apply would disrupt it, least disruptive first, so the rollout can be
    sequenced onto dormant projects before busy ones.

    .DESCRIPTION
    This is a read-only, one-off sequencing helper for a project-wide branch-policy rollout,
    not module code - it is run interactively by an engineer and makes no writes of any kind.

    Activity definition. The three policies the rollout applies (minimum reviewers, work
    item linking, comment resolution) are blocking policies on the default
    branch, so they do two things: they gate pull-request completion, and they make the
    default branch reject direct pushes. Both effects are measured:

      Pull-request recency, the primary ranking key, from the project-scoped API

        GET {org}/{projectId}/_apis/git/pullrequests?searchCriteria.status=all&$top=N

      searchCriteria.status=all is mandatory. The API defaults to 'active' only, so a
      dormant project - exactly the kind being hunted here - would return an empty array
      and read as "never had a pull request" when it has fifty, all closed last year. The
      API returns newest-first (descending pullRequestId), so a small $top window is
      enough; the window is scanned for the greatest of creationDate and closedDate, since
      the sort is on creation and a long-lived pull request can be closed later than a
      newer one was created.

      Push recency, read ONLY for projects whose pull-request history is empty, from

        GET {org}/_apis/git/repositories/{repositoryId}/pushes?$top=1

      (the project segment is omittable - repository IDs are globally unique). This is the
      disqualifier that stops the ranking inverting. A project with no pull requests but
      live direct pushes to its default branch is the HIGHEST-disruption target, not the
      lowest: every one of those pushes starts failing the day the policy lands. Without
      this read, "busy repo nobody raises pull requests on" is indistinguishable from
      "dormant repo nobody touches", and the first would sort to the top of the apply list.
      Pushes come back newest-first, so $top=1 is the latest.

    Project lastUpdateTime is emitted for context only and is never ranked on: it moves on
    project renames and process-template changes, which say nothing about whether people
    are shipping code.

    Projects are bucketed into RiskBucket (least disruptive first), then sorted within the
    bucket by the date that matters for it:

      NoRepositories             - nothing to police, apply first
      NoPullRequestsNoPushes     - repositories exist but are dead, safe
      PullRequestHistory         - sorted oldest pull request first
      NoPullRequestsRecentPushes - direct-push workflow, HOLD BACK from the first wave
      Failed                     - read failed, excluded from the apply candidates

    Failure handling. A project whose read throws is reported with Status 'Failed' and is
    sorted LAST, never first - a failed read must never be mistaken for a dormant project
    and applied to ahead of a genuinely quiet one.

    Every project-scoped call addresses the project by ID rather than name, so a project
    name containing spaces or other URL-significant characters needs no escaping.

    .PARAMETER Organization
    Azure DevOps organisation URL, e.g. https://dev.azure.com/{org}.

    .PARAMETER AccessToken
    Optional bearer token for the Azure DevOps REST API. When omitted, a token is acquired
    via Get-AzAccessToken against the Azure DevOps resource ID, matching the pattern used
    by the branch-policy tooling this rollout relies on.

    .PARAMETER PullRequestSampleSize
    Number of most-recent pull requests read per project when looking for the newest
    timestamp. The API returns them newest-created first, so a small window is sufficient;
    a larger one only widens the guard against a long-lived pull request closed after a
    newer one was created.

    .PARAMETER ProjectPageSize
    Number of projects requested per page from the Projects - List API.

    .PARAMETER MaxProjectPages
    Safety bound on the number of project pages fetched, to avoid an infinite loop if the
    Projects - List API ignores $skip.

    .OUTPUTS
    [pscustomobject] One row per project, least disruptive first: Project, ProjectId,
    State, RiskBucket, RepositoryCount, LastPullRequestUtc, DaysSinceLastPullRequest,
    LastPushUtc, DaysSinceLastPush, LastUpdateTimeUtc, Status (Read/Failed), ErrorMessage.

    .EXAMPLE
    ./Get-AdoProjectActivity.ps1 | Format-Table -AutoSize

    .EXAMPLE
    ./Get-AdoProjectActivity.ps1 | Export-Csv -Path ./project-activity.csv -NoTypeInformation
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Organization,

    [Parameter(Mandatory = $false)]
    [securestring] $AccessToken,

    [Parameter(Mandatory = $false)]
    [int] $PullRequestSampleSize = 20,

    [Parameter(Mandatory = $false)]
    [int] $ProjectPageSize = 100,

    [Parameter(Mandatory = $false)]
    [int] $MaxProjectPages = 50
)

. "$PSScriptRoot/Private/Invoke-AdoRestMethodWithRetry.ps1"
. "$PSScriptRoot/Private/Get-AdoBranchPolicyEligibleRepository.ps1"
. "$PSScriptRoot/Private/ConvertTo-AdoUtcDateTime.ps1"

function Get-AdoOrganizationProject {
    <#
        .SYNOPSIS
        Pages the Projects - List API and returns the full project objects (id, name,
        state, lastUpdateTime), not just the names.

        .DESCRIPTION
        Uses $top/$skip rather than the header-borne continuation token, matching the
        organisation-project-name module helper elsewhere in this toolset. That helper
        returns [string[]] names only, which discards the id, state and lastUpdateTime
        this report needs, so the paging loop is repeated here rather than the helper
        being reused.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [int] $PageSize,

        [Parameter(Mandatory = $true)]
        [int] $MaxPages
    )

    $projects = [System.Collections.Generic.List[object]]::new()
    $skip = 0
    $pagesFetched = 0
    do {
        $listUri = "$Organization/_apis/projects?api-version=7.1&`$top=$PageSize&`$skip=$skip"
        Write-Verbose -Message "Fetching project page at skip=$skip (top=$PageSize)."
        $page = Invoke-AdoRestMethodWithRetry -Parameters @{
            Uri = $listUri
            Method = 'Get'
            Headers = $Headers
        }
        $pageProjects = @($page.value)
        if ($pageProjects.Count -gt 0) {
            $pagesFetched++
            if ($pagesFetched -gt $MaxPages) {
                throw "Project enumeration for organisation '$Organization' exceeded " +
                "$MaxPages pages ($($projects.Count) projects collected so far). The " +
                "Projects - List API may be ignoring `$skip; aborting to avoid an " +
                'infinite loop. Increase -MaxProjectPages if this organisation genuinely ' +
                'has that many projects.'
            }

            foreach ($pageProject in $pageProjects) {
                $projects.Add($pageProject)
            }
            $skip += $pageProjects.Count
        }
    } while ($pageProjects.Count -gt 0)
    Write-Verbose -Message "Enumerated $($projects.Count) project(s) across $pagesFetched page(s)."

    return $projects.ToArray()
}

function Get-AdoProjectLastPullRequestUtc {
    <#
        .SYNOPSIS
        Returns the most recent pull-request timestamp in a project, or $null when the
        project has never had one.

        .DESCRIPTION
        Reads the newest -SampleSize pull requests of ANY status and returns the greatest
        of their creationDate and closedDate values. status=all is required: the API
        defaults to active-only, which silently reports a dormant project as having no
        pull-request history at all.
    #>
    [CmdletBinding()]
    [OutputType([System.Nullable[datetime]])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [int] $SampleSize
    )

    $pullRequestUri = "$Organization/$ProjectId/_apis/git/pullrequests" +
    "?api-version=7.1&searchCriteria.status=all&`$top=$SampleSize"
    $response = Invoke-AdoRestMethodWithRetry -Parameters @{
        Uri = $pullRequestUri
        Method = 'Get'
        Headers = $Headers
    }

    $latest = $null
    foreach ($pullRequest in @($response.value)) {
        foreach ($field in @($pullRequest.creationDate, $pullRequest.closedDate)) {
            $candidate = ConvertTo-AdoUtcDateTime -Value $field
            if ($null -ne $candidate -and ($null -eq $latest -or $candidate -gt $latest)) {
                $latest = $candidate
            }
        }
    }
    return $latest
}

function Get-AdoRepositoryListLastPushUtc {
    <#
        .SYNOPSIS
        Returns the most recent push timestamp across a set of repositories, or $null when
        none of them has ever been pushed to.

        .DESCRIPTION
        The Pushes - List API returns pushes newest-first, so $top=1 is the latest push.
        The push date is stamped by the server, unlike a commit's author date, so it cannot
        be backdated by a rewritten history. Repository IDs are globally unique, so the
        project segment is omitted from the URI.
    #>
    [CmdletBinding()]
    [OutputType([System.Nullable[datetime]])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $Repository,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers
    )

    $latest = $null
    foreach ($repo in $Repository) {
        $pushUri = "$Organization/_apis/git/repositories/$($repo.id)/pushes" +
        "?api-version=7.1&`$top=1"
        $response = Invoke-AdoRestMethodWithRetry -Parameters @{
            Uri = $pushUri
            Method = 'Get'
            Headers = $Headers
        }
        foreach ($push in @($response.value)) {
            $candidate = ConvertTo-AdoUtcDateTime -Value $push.date
            if ($null -ne $candidate -and ($null -eq $latest -or $candidate -gt $latest)) {
                $latest = $candidate
            }
        }
    }
    return $latest
}

if (-not $AccessToken) {
    Write-Verbose -Message 'No -AccessToken supplied; acquiring one via Get-AzAccessToken.'
    $AccessToken = (Get-AzAccessToken -AsSecureString -ResourceUrl '499b84ac-1321-427f-aa17-267ca6975798').Token
}

$plainTextAccessToken = [System.Net.NetworkCredential]::new('', $AccessToken).Password
$headers = @{ Authorization = "Bearer $plainTextAccessToken" }

$projectListParameters = @{
    Organization = $Organization
    Headers = $headers
    PageSize = $ProjectPageSize
    MaxPages = $MaxProjectPages
}
$projects = Get-AdoOrganizationProject @projectListParameters

# Bucket rank drives the primary sort; the labels are also emitted as RiskBucket so the
# reason a project sits where it does is visible in the output rather than implied.
$bucketRanks = @{
    NoRepositories = 0
    NoPullRequestsNoPushes = 1
    PullRequestHistory = 2
    NoPullRequestsRecentPushes = 3
    Failed = 4
}

$now = [datetime]::UtcNow
$rows = [System.Collections.Generic.List[pscustomobject]]::new()

foreach ($project in $projects) {
    $projectName = [string]$project.name
    $projectId = [string]$project.id
    Write-Verbose -Message "Reading activity for project '$projectName' ($projectId)."

    try {
        $projectScopeParameters = @{
            Organization = $Organization
            Project = $projectId
            Headers = $headers
        }
        $repositories = @(Get-AdoBranchPolicyEligibleRepository @projectScopeParameters)

        $pullRequestParameters = @{
            Organization = $Organization
            ProjectId = $projectId
            Headers = $headers
            SampleSize = $PullRequestSampleSize
        }
        $lastPullRequestUtc = Get-AdoProjectLastPullRequestUtc @pullRequestParameters

        # Pushes are read only when there is no pull-request history: that is the one case
        # where pull-request recency alone cannot separate a dead project from a busy
        # direct-push one, and it keeps the per-repository loop off the whole org.
        $lastPushUtc = $null
        if ($null -eq $lastPullRequestUtc -and $repositories.Count -gt 0) {
            $pushParameters = @{
                Organization = $Organization
                Repository = $repositories
                Headers = $headers
            }
            $lastPushUtc = Get-AdoRepositoryListLastPushUtc @pushParameters
        }

        $bucket = if ($repositories.Count -eq 0) {
            'NoRepositories'
        } elseif ($null -ne $lastPullRequestUtc) {
            'PullRequestHistory'
        } elseif ($null -ne $lastPushUtc) {
            'NoPullRequestsRecentPushes'
        } else {
            'NoPullRequestsNoPushes'
        }

        $rows.Add([pscustomobject]@{
                Project = $projectName
                ProjectId = $projectId
                State = [string]$project.state
                RiskBucket = $bucket
                RepositoryCount = $repositories.Count
                LastPullRequestUtc = $lastPullRequestUtc
                DaysSinceLastPullRequest = if ($null -eq $lastPullRequestUtc) {
                    $null
                } else {
                    [math]::Round(($now - $lastPullRequestUtc).TotalDays, 1)
                }
                LastPushUtc = $lastPushUtc
                DaysSinceLastPush = if ($null -eq $lastPushUtc) {
                    $null
                } else {
                    [math]::Round(($now - $lastPushUtc).TotalDays, 1)
                }
                LastUpdateTimeUtc = ConvertTo-AdoUtcDateTime -Value $project.lastUpdateTime
                Status = 'Read'
                ErrorMessage = $null
            })
    } catch {
        Write-Warning -Message "Failed to read activity for project '$projectName': $($_.Exception.Message)"
        $rows.Add([pscustomobject]@{
                Project = $projectName
                ProjectId = $projectId
                State = [string]$project.state
                RiskBucket = 'Failed'
                RepositoryCount = $null
                LastPullRequestUtc = $null
                DaysSinceLastPullRequest = $null
                LastPushUtc = $null
                DaysSinceLastPush = $null
                LastUpdateTimeUtc = ConvertTo-AdoUtcDateTime -Value $project.lastUpdateTime
                Status = 'Failed'
                ErrorMessage = $_.Exception.Message
            })
    }
}

$bucketSortKey = { $bucketRanks[$_.RiskBucket] }

# Within a bucket, sort by the date that bucket is actually about: oldest pull request
# first where there is pull-request history, oldest push first for the direct-push bucket.
# Both are projected explicitly rather than leaning on how Sort-Object orders $null,
# because a blank date means "never happened" in one bucket and "not read" in another.
$dateSortKey = {
    if ($_.RiskBucket -eq 'PullRequestHistory') {
        return [datetime]$_.LastPullRequestUtc
    }
    if ($_.RiskBucket -eq 'NoPullRequestsRecentPushes') {
        return [datetime]$_.LastPushUtc
    }
    return [datetime]::MinValue
}

return $rows | Sort-Object -Property $bucketSortKey, $dateSortKey, 'Project'
