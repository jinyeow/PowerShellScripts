#Requires -Version 5.1

<#
    .SYNOPSIS
    Root module for SampleModule.

    .DESCRIPTION
    Dot-sources every public function under Public/ and exports them. Used as a
    reference module to exercise the build, test and publish pipeline.
#>

$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
if (-not (Test-Path -Path $publicPath)) {
    throw "Public directory not found at '$publicPath'."
}

$publicFunctions = Get-ChildItem -Path $publicPath -Filter '*.ps1'

foreach ($function in $publicFunctions) {
    . $function.FullName
}

if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}
