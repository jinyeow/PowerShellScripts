<#
    .DESCRIPTION
    PSScriptAnalyzer is a static code checker for PowerShell modules and scripts.
    PSScriptAnalyzer checks the quality of PowerShell code by running a set of rules.
    The rules are based on PowerShell best practices identified by PowerShell Team and the community.
    It generates DiagnosticResults (errors and warnings) to inform users about potential code
    defects and suggests possible solutions for improvements.

    .NOTES
    The below link will show additional information relating to this module:
    https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview
    The below link will show rules configurable:
    https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/readme
#>

@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @('PSAvoidUsingWriteHost')
    Rules        = @{
        PSAvoidLongLines                            = @{
            Enable            = $true
            MaximumLineLength = 115
        }
        PSAvoidSemicolonsAsLineTerminators          = @{
            Enable = $true
        }
        PSAvoidTrailingWhitespace                   = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases                   = @{
            Enable = $true
        }
        PSMisleadingBacktick                        = @{
            Enable = $true
        }
        PSMissingModuleManifestField                = @{
            Enable = $true
        }
        PSPlaceCloseBrace                           = @{
            Enable             = $true
            NoEmptyLineBefore  = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $false
        }
        PSPlaceOpenBrace                            = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPossibleIncorrectComparisonWithNull       = @{
            Enable = $true
        }
        PSProvideCommentHelp                        = @{
            Enable = $true
        }
        PSUseApprovedVerbs                          = @{
            Enable = $true
        }
        PSUseCompatibleSyntax                       = @{
            Enable         = $true
            TargetVersions = @(
                '7.0',
                '6.0',
                '5.0'
            )
        }
        PSUseConsistentIndentation                  = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace                   = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSUseCorrectCasing                          = @{
            Enable        = $true
            CheckCommands = $true
            CheckKeyword  = $true
            CheckOperator = $true
        }
        PSUseOutputTypeCorrectly                    = @{
            Enable = $true
        }
        PSUseProcessBlockForPipelineCommand         = @{
            Enable = $true
        }
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
        PSUseSingularNouns                          = @{
            Enable = $true
        }
        PSUseSupportsShouldProcess                  = @{
            Enable = $true
        }
    }
}
