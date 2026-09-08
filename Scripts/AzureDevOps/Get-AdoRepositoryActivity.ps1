#Requires -Version 7.0

<#
    .SYNOPSIS
    Reports per-repository push activity and main pusher(s) for one Azure DevOps project,
    so a large project held out of the PBI 650872 branch-policy rollout can be judged repo
    by repo instead of on a single project-level aggregate.

    .DESCRIPTION
    This is a read-only, one-off helper for the PBI 650872 rollout, not module code - it is
    run interactively by an engineer and makes no writes of any kind. It is the per-repo
    counterpart to Get-AdoProjectActivity.ps1, which classifies whole projects; that script
    answers "which projects are safe to apply to next", this one answers "inside one held
    project, which repositories are still being worked on and by whom".

    Why pushes rather than commits. Every row is built from

      GET {org}/_apis/git/repositories/{repositoryId}/pushes?$top=N

    which returns, in one call per repository, both fields this report needs: pushedBy (a
    real Azure DevOps identity, the person to talk to for owner confirmation) and a
    server-stamped date. The push date cannot be backdated by a rewritten history the way a
    commit's author date can - the same rationale Get-AdoProjectActivity.ps1 documents.
    Repository IDs are globally unique, so the project segment is omitted from the URI.

    One call per repository is the batched form. Azure DevOps has no organisation-wide or
    project-wide push or commit query: pushes and commits are only addressable per
    repository, so a project with N repositories costs N calls plus one repository listing
    and one project listing. There is no pagination trick that collapses them.

    Disabled repositories are INCLUDED, unlike Get-AdoBranchPolicyEligibleRepository, which
    filters them out. For a "is this project winding down" judgement a disabled repository
    is evidence, not noise, so the raw Repositories - List response is used and isDisabled
    is carried as a column. This means RepositoryCount here can exceed the count the
    branch-policy audit reports for the same project. A disabled repository usually cannot
    be read for pushes at all, so it lands as Status 'Failed' with ActivityBand 'Unknown';
    a row with IsDisabled true and Status 'Failed' means "disabled", not "unreadable", and
    is among the strongest winding-down evidence in the set.

    Activity bands are fixed here, before the data is seen, so the judgement is falsifiable.
    They are read off DaysSinceLastPush:

      Active      - pushed within the last 30 days
      Slowing     - last push 31-90 days ago
      WindingDown - last push 91-180 days ago
      Dormant     - last push more than 180 days ago
      Never       - the repository has never been pushed to
      Unknown     - the read failed (Status 'Failed'); never treated as dormant

    Sample-window caveat. DistinctPushers, TopPusher and PushesPerDay describe only the
    newest -PushSampleSize pushes, not the repository's whole history. ReturnedPushCount is
    emitted on every row so a window that came back full (equal to -PushSampleSize) is
    visible as truncated rather than being mistaken for a complete history. The script also
    reports the first repository's returned count to the verbose stream, so the API's actual
    $top ceiling can be checked against the requested value on a real run instead of assumed.

    .PARAMETER Organization
    Azure DevOps organisation URL, e.g. https://dev.azure.com/HollardInsuranceRetail.

    .PARAMETER ProjectName
    Name of the project to report on. Resolved to a project ID before any project-scoped
    call, so a name containing spaces needs no escaping.

    .PARAMETER AccessToken
    Optional bearer token for the Azure DevOps REST API. When omitted, a token is acquired
    via Get-AzAccessToken against the Azure DevOps resource ID, matching the pattern used by
    Get-AdoProjectActivity.ps1 and Set-AdoBranchPolicyProject.

    .PARAMETER PushSampleSize
    Number of most-recent pushes read per repository. Pushes come back newest-first, so this
    is a recency window: raising it widens the window used for DistinctPushers, TopPusher and
    PushesPerDay without changing LastPushUtc.

    .PARAMETER OutFile
    Optional path for a CSV of the per-repository rows. When omitted, the rows are only
    returned to the pipeline.

    .OUTPUTS
    [pscustomobject] One row per repository: Repo, IsDisabled, LastPushUtc,
    DaysSinceLastPush, ActivityBand, TopPusher, TopPusherPushCount, DistinctPushers,
    ReturnedPushCount, SampleWindowDays, PushesPerDay, Status, ErrorMessage.

    .EXAMPLE
    ./Get-AdoRepositoryActivity.ps1 -ProjectName 'CBA Historical Pricing' -Verbose |
        Format-Table -AutoSize

    .EXAMPLE
    ./Get-AdoRepositoryActivity.ps1 -ProjectName 'CBA Historical Pricing' -OutFile ./cba-repo-activity.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Organization,

    [Parameter(Mandatory = $true)]
    [string] $ProjectName,

    [Parameter(Mandatory = $false)]
    [securestring] $AccessToken,

    [Parameter(Mandatory = $false)]
    [int] $PushSampleSize = 100,

    [Parameter(Mandatory = $false)]
    [string] $OutFile
)

. "$PSScriptRoot/../src/Private/Invoke-AdoRestMethodWithRetry.ps1"

function ConvertTo-AdoUtcDateTime {
    <#
        .SYNOPSIS
        Normalises an Azure DevOps date-time field to UTC, whether Invoke-RestMethod handed
        it back as a string or as an already-parsed DateTime.
    #>
    [CmdletBinding()]
    [OutputType([System.Nullable[datetime]])]
    param(
        [Parameter(Mandatory = $false)]
        [object] $Value
    )

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [datetime]) {
        return ([datetime]$Value).ToUniversalTime()
    }
    $text = [string]$Value
    if (-not $text) {
        return $null
    }
    $parsed = [datetime]::Parse(
        $text,
        [cultureinfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    )
    return $parsed.ToUniversalTime()
}

function Resolve-AdoProjectId {
    <#
        .SYNOPSIS
        Returns the project ID for a project name, so every later call can address the
        project by ID and avoid URL-escaping a name containing spaces.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $ProjectName,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers
    )

    $skip = 0
    $pageSize = 100
    $maxPages = 50
    $pagesFetched = 0
    do {
        $listUri = "$Organization/_apis/projects?api-version=7.1&`$top=$pageSize&`$skip=$skip"
        $page = Invoke-AdoRestMethodWithRetry -Parameters @{
            Uri = $listUri
            Method = 'Get'
            Headers = $Headers
        }
        $pageProjects = @($page.value)
        if ($pageProjects.Count -gt 0) {
            $pagesFetched++
            # Same guard as Get-AdoProjectActivity.ps1: bound the loop in case the
            # Projects - List API ignores $skip and keeps returning the first page.
            if ($pagesFetched -gt $maxPages) {
                throw "Project enumeration for organisation '$Organization' exceeded " +
                "$maxPages pages without finding '$ProjectName'. The Projects - List API " +
                'may be ignoring $skip; aborting to avoid an infinite loop.'
            }
        }
        $match = $pageProjects | Where-Object { $_.name -eq $ProjectName } | Select-Object -First 1
        if ($match) {
            return [string]$match.id
        }
        $skip += $pageProjects.Count
    } while ($pageProjects.Count -gt 0)

    throw "Project '$ProjectName' was not found in organisation '$Organization'. Check the " +
    'exact project name against the Projects - List API (the match is case-insensitive, so a ' +
    'miss means the name itself differs, not just its casing).'
}

function Get-AdoRepositoryPushSample {
    <#
        .SYNOPSIS
        Returns the newest -SampleSize pushes for one repository, newest first.

        .DESCRIPTION
        The Pushes - List API returns pushes newest-first, so the returned set is a recency
        window. Repository IDs are globally unique, so the project segment is omitted.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $RepositoryId,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [int] $SampleSize
    )

    $pushUri = "$Organization/_apis/git/repositories/$RepositoryId/pushes" +
    "?api-version=7.1&`$top=$SampleSize"
    $response = Invoke-AdoRestMethodWithRetry -Parameters @{
        Uri = $pushUri
        Method = 'Get'
        Headers = $Headers
    }
    return @($response.value)
}

function Get-AdoActivityBand {
    <#
        .SYNOPSIS
        Maps days-since-last-push onto the fixed activity bands documented in this script's
        help, so the thresholds live in exactly one place.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [System.Nullable[double]] $DaysSinceLastPush
    )

    if ($null -eq $DaysSinceLastPush) {
        return 'Never'
    }
    if ($DaysSinceLastPush -le 30) {
        return 'Active'
    }
    if ($DaysSinceLastPush -le 90) {
        return 'Slowing'
    }
    if ($DaysSinceLastPush -le 180) {
        return 'WindingDown'
    }
    return 'Dormant'
}

if (-not $AccessToken) {
    Write-Verbose -Message 'No -AccessToken supplied; acquiring one via Get-AzAccessToken.'
    $AccessToken = (Get-AzAccessToken -AsSecureString -ResourceUrl '499b84ac-1321-427f-aa17-267ca6975798').Token
}

$plainTextAccessToken = [System.Net.NetworkCredential]::new('', $AccessToken).Password
$headers = @{ Authorization = "Bearer $plainTextAccessToken" }

$projectId = Resolve-AdoProjectId -Organization $Organization -ProjectName $ProjectName -Headers $headers
Write-Verbose -Message "Resolved project '$ProjectName' to id $projectId."

# The raw listing is used rather than Get-AdoBranchPolicyEligibleRepository: that helper
# drops disabled repositories, and a disabled repository is evidence for this report.
$reposUri = "$Organization/$projectId/_apis/git/repositories?api-version=7.1"
$reposResponse = Invoke-AdoRestMethodWithRetry -Parameters @{
    Uri = $reposUri
    Method = 'Get'
    Headers = $headers
}
$repositories = @($reposResponse.value)
Write-Verbose -Message ("Project '$ProjectName' has $($repositories.Count) " +
    'repository/repositories (disabled included).')

$now = [datetime]::UtcNow
$rows = [System.Collections.Generic.List[pscustomobject]]::new()
$isFirstRepository = $true

foreach ($repository in $repositories) {
    $repositoryName = [string]$repository.name
    Write-Verbose -Message "Reading pushes for repository '$repositoryName'."

    try {
        $pushSampleParameters = @{
            Organization = $Organization
            RepositoryId = [string]$repository.id
            Headers = $headers
            SampleSize = $PushSampleSize
        }
        $pushes = @(Get-AdoRepositoryPushSample @pushSampleParameters)

        if ($isFirstRepository) {
            # Empirical check on the API's real $top ceiling: a returned count below the
            # requested one on a busy repository would mean the window is capped lower.
            Write-Verbose -Message ("First repository '$repositoryName' returned " +
                "$($pushes.Count) push(es) for a requested `$top of $PushSampleSize.")
            $isFirstRepository = $false
        }

        $pushDates = @(
            foreach ($push in $pushes) {
                $pushDate = ConvertTo-AdoUtcDateTime -Value $push.date
                if ($null -ne $pushDate) {
                    $pushDate
                }
            }
        )
        $pusherNames = @(
            foreach ($push in $pushes) {
                $pusherName = [string]$push.pushedBy.displayName
                if ($pusherName) {
                    $pusherName
                }
            }
        )

        $lastPushUtc = if ($pushDates.Count -gt 0) {
            ($pushDates | Measure-Object -Maximum).Maximum
        } else {
            $null
        }
        $oldestPushUtc = if ($pushDates.Count -gt 0) {
            ($pushDates | Measure-Object -Minimum).Minimum
        } else {
            $null
        }
        $daysSinceLastPush = if ($null -eq $lastPushUtc) {
            $null
        } else {
            [math]::Round(($now - $lastPushUtc).TotalDays, 1)
        }
        $sampleWindowDays = if ($null -eq $lastPushUtc -or $null -eq $oldestPushUtc) {
            $null
        } else {
            [math]::Round(($lastPushUtc - $oldestPushUtc).TotalDays, 1)
        }
        $pushesPerDay = if ($null -eq $sampleWindowDays -or $sampleWindowDays -le 0) {
            $null
        } else {
            [math]::Round($pushes.Count / $sampleWindowDays, 2)
        }

        $topPusherGroup = $pusherNames |
            Group-Object |
            Sort-Object -Property Count -Descending |
            Select-Object -First 1

        $rows.Add([pscustomobject]@{
                Repo = $repositoryName
                IsDisabled = [bool]$repository.isDisabled
                LastPushUtc = $lastPushUtc
                DaysSinceLastPush = $daysSinceLastPush
                ActivityBand = Get-AdoActivityBand -DaysSinceLastPush $daysSinceLastPush
                TopPusher = if ($topPusherGroup) { [string]$topPusherGroup.Name } else { $null }
                TopPusherPushCount = if ($topPusherGroup) { [int]$topPusherGroup.Count } else { $null }
                DistinctPushers = ($pusherNames | Sort-Object -Unique).Count
                ReturnedPushCount = $pushes.Count
                SampleWindowDays = $sampleWindowDays
                PushesPerDay = $pushesPerDay
                Status = if ($pushes.Count -eq 0) { 'NoPushes' } else { 'Read' }
                ErrorMessage = $null
            })
    } catch {
        Write-Warning -Message "Failed to read pushes for repository '$repositoryName': $($_.Exception.Message)"
        $rows.Add([pscustomobject]@{
                Repo = $repositoryName
                IsDisabled = [bool]$repository.isDisabled
                LastPushUtc = $null
                DaysSinceLastPush = $null
                ActivityBand = 'Unknown'
                TopPusher = $null
                TopPusherPushCount = $null
                DistinctPushers = $null
                ReturnedPushCount = $null
                SampleWindowDays = $null
                PushesPerDay = $null
                Status = 'Failed'
                ErrorMessage = $_.Exception.Message
            })
    }
}

if ($rows.Count -ne $repositories.Count) {
    throw "Row count ($($rows.Count)) does not match repository count ($($repositories.Count)) " +
    "for project '$ProjectName'. Every repository must produce exactly one row, including " +
    'repositories that have never been pushed to and repositories whose read failed.'
}

# Most recently pushed first. A repository with no push (or a failed read) has no date at
# all, so it is projected to the far end explicitly rather than relying on how Sort-Object
# orders $null - "never pushed" must not sort alongside "pushed today".
$recencySortKey = {
    if ($null -eq $_.DaysSinceLastPush) {
        return [double]::MaxValue
    }
    return [double]$_.DaysSinceLastPush
}
$sortedRows = $rows | Sort-Object -Property $recencySortKey, 'Repo'

if ($OutFile) {
    $sortedRows | Export-Csv -Path $OutFile -NoTypeInformation
    Write-Verbose -Message "Wrote $($sortedRows.Count) row(s) to '$OutFile'."
}

# Console aggregate, written to the information stream so it never contaminates the objects
# returned to the pipeline or the CSV.
$informationSplat = @{ InformationAction = 'Continue' }
Write-Information -MessageData "Project '$ProjectName': $($repositories.Count) repo(s)." @informationSplat
$bandSummary = $sortedRows |
    Group-Object -Property ActivityBand |
    Sort-Object -Property Count -Descending |
    ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Information -MessageData "Activity bands: $($bandSummary -join ', ')." @informationSplat
$topPushers = $sortedRows |
    Where-Object { $_.TopPusher } |
    Group-Object -Property TopPusher |
    Sort-Object -Property Count -Descending |
    Select-Object -First 5 |
    ForEach-Object { "$($_.Name) ($($_.Count) repo(s))" }
Write-Information -MessageData "Top pushers by repo count: $($topPushers -join '; ')." @informationSplat

return $sortedRows
