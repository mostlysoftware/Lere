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
  Prune = @{
    # Number of files above which a prune proposal requires review (default: 3)
    Threshold = 3
    # If true, proposals that are explicitly labeled with Risk='low' and Impact='high'
    # will be auto-approved (manifest will be marked Approved=true) and may be applied
    # without opening a PR when the operator chooses. Default is false for safety.
    AutoApproveHighImpactLowRisk = $false
  }
  Backup = @{
    # How many days to retain snapshots (0 = keep forever)
    RetentionDays = 30
  }
  Onboarding = @{
    QuickStart = 'Run .\scripts\health_check.ps1 -Scope all -Report console ; see scripts/audit-data for JSON reports and manifests'
    MemoryPath = 'chat_context (Memory File headers present)'
  }
  Health = @{
    AssertScriptsUpToDate = $false
    ScopeCreep = @{
      # Context-level thresholds for open questions
      MaxOpenQuestions = 10
      MaxHighPriorityOpen = 0
      MaxDeferredQuestions = 20

      # Project-level thresholds for outstanding findings
      MaxProjectWarnings = 5
      MaxProjectErrors = 0
    }
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
