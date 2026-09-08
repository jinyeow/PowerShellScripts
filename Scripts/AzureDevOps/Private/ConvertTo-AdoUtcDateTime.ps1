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
