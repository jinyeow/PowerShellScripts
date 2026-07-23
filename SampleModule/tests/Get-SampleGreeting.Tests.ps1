#Requires -Modules Pester

BeforeAll {
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $manifestPath = Join-Path -Path $moduleRoot -ChildPath 'src/SampleModule.psd1'
    Import-Module -Name $manifestPath -Force
}

AfterAll {
    Remove-Module -Name 'SampleModule' -Force -ErrorAction SilentlyContinue
}

Describe 'Get-SampleGreeting' {
    It 'greets the supplied name' {
        Get-SampleGreeting -Name 'Ada' | Should -Be 'Hello, Ada!'
    }

    It 'defaults to World when no name is supplied' {
        Get-SampleGreeting | Should -Be 'Hello, World!'
    }

    It 'throws when the name is empty' {
        { Get-SampleGreeting -Name '' } | Should -Throw
    }
}
