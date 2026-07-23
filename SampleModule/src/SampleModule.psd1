@{
    RootModule        = 'SampleModule.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'd3f5a9c1-6b2e-4c7a-9f0d-8e1b2a4c6d7f'
    Author            = 'PowerShellScripts Contributors'
    CompanyName       = 'PowerShellScripts'
    Copyright         = '(c) PowerShellScripts Contributors. All rights reserved.'
    Description       = 'Sample module used to validate the Azure Artifacts publish pipeline end to end.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-SampleGreeting')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Sample', 'Example', 'PSModule')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/jinyeow/PowerShellScripts'
            ReleaseNotes = 'Initial sample module for pipeline validation.'
            # Prerelease is stamped by CI for non-main branches; leave it unset here.
        }
    }
}
