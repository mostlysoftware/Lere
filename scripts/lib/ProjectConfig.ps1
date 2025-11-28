<#
.SYNOPSIS
  Centralized project configuration used by health checks and tools.

.DESCRIPTION
  Stores defaults for duplicate detection, excludes, and thresholds that
  should be consistent across tools and CI.
#>

$ProjectConfig = @{
  Duplicate = @{
    MinLines = 8
    ExcludePaths = @(
      'scripts/lib',
      'chat_context/archives',
      'scripts/audit-data',
      'scripts/audit-data/archive'
    )
    Extensions = @('.md', '.ps1')
    # If a block appears this many times total, consider centralization
    CentralizeOccurrenceThreshold = 3
    # If a block appears across this many distinct files, suggest centralization
    CentralizeDistinctFileThreshold = 2
  }
  FileHygiene = @{
    MaxFileSizeKB = 120
    MaxFileLines = 1200
    Extensions = @('.ps1','.md','.java','.kt','.yml','.json')
  }
  PowerShell = @{
    MaxFunctionLines = 200
  }
  Audit = @{
    OutDir = 'scripts/audit-data'
  KeepReports = 10
  }
  Onboarding = @{
    QuickStart = 'Run .\scripts\health_check.ps1 -Scope all -Report console ; see scripts/audit-data for JSON reports and manifests'
    MemoryPath = 'chat_context (Memory File headers present)'
  }
  ReasoningCritique = @{
    Enabled = $true
    MaxLines = 400
    QuestionThreshold = 3
    VerbosePenalty = 10
    NoSummaryPenalty = 20
    ManyQuestionsPenalty = 15
    ContradictionPenalty = 30
    # Threads scoring below this value will be reported as warnings
    ScoreWarningThreshold = 60
    # LLM-backed suggestions are opt-in (false by default)
    UseLLM = $false
    LLMModel = ''
    LLMTimeoutSeconds = 10
  }
}
