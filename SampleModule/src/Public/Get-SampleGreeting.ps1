function Get-SampleGreeting {
    <#
        .SYNOPSIS
        Returns a friendly greeting for the supplied name.

        .DESCRIPTION
        Sample public function used to exercise the build, test and publish
        pipeline end to end.

        .PARAMETER Name
        The name to greet. Defaults to 'World'.

        .EXAMPLE
        Get-SampleGreeting -Name 'Ada'

        Returns 'Hello, Ada!'.

        .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name = 'World'
    )

    return "Hello, $Name!"
}
