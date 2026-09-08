<#
    .SYNOPSIS
    Calls Invoke-RestMethod, retrying transient failures with a warning before
    raising the last error.
#>
function Invoke-AdoRestMethodWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $Parameters,

        [Parameter(Mandatory = $false)]
        [int] $MaxAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int] $RetryDelaySeconds = 2
    )

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-RestMethod @Parameters
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            # A non-idempotent write (e.g. Post) must not be retried on an ambiguous failure
            # (no status code, meaning the client never saw the response): the request may have
            # already succeeded server-side, and a retry would create a duplicate resource. Only
            # retry a Post when the server itself returned a definite transient status code,
            # which confirms it did not complete the request.
            $isDefiniteTransientStatusCode = $statusCode -eq 429 -or $statusCode -ge 500
            $isTransient = if ($Parameters.Method -eq 'Post') {
                $isDefiniteTransientStatusCode
            } else {
                (-not $statusCode) -or $statusCode -eq 408 -or $isDefiniteTransientStatusCode
            }
            $responseBody = Get-AdoErrorResponseBody -ErrorRecord $_
            $messageParts = @(
                "Azure DevOps REST call to '$($Parameters.Uri)' failed (status: $statusCode):"
                "$($_.Exception.Message). Response: $responseBody"
            )
            $errorMessage = $messageParts -join ' '

            if (-not $isTransient -or $attempt -ge $MaxAttempts) {
                $enrichedException = [System.Exception]::new($errorMessage, $_.Exception)
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $enrichedException, $_.FullyQualifiedErrorId, $_.CategoryInfo.Category, $_.TargetObject
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            Write-Warning -Message "$errorMessage (attempt $attempt of ${MaxAttempts}, retrying)"
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

<#
    .SYNOPSIS
    Extracts the response body text from a failed REST call, if any is available.
#>
function Get-AdoErrorResponseBody {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $errorDetails = $ErrorRecord.ErrorDetails.Message
    if ($errorDetails) {
        return $errorDetails
    }
    return '<no response body>'
}
