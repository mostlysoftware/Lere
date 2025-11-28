<#
ReasoningCritique.ps1

Conservative, rule-based analyzer for reasoning threads.

Public functions:
 - Analyze-ReasoningThread -Text -Name -Config
 - Scan-ReasoningCorpus -Root -IncludeArchives -Config
 - Write-ReasoningCritiqueReport -OutDir -Data

This initial implementation uses heuristic checks only (no external LLM).
It's designed to be safe (read-only) and opt-in via health_check.
#>

function Analyze-ReasoningThread {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)] [string]$Text,
    [Parameter(Mandatory=$false)] [string]$Name = 'Unnamed',
    [Parameter(Mandatory=$false)] [hashtable]$Config = @{}
  )

  $cfg = @{
    MaxLines = 400
    VerbosePenalty = 10
    NoSummaryPenalty = 20
    ManyQuestionsPenalty = 15
    ContradictionPenalty = 30
    QuestionThreshold = 3
  }
  if ($Config -and $Config.Keys.Count -gt 0) {
    foreach ($k in $Config.Keys) { $cfg[$k] = $Config[$k] }
  }

  # Normalize text and compute metadata
  $lines = ($Text -split '\r?\n') | ForEach-Object { $_.Trim() }
  $lineCount = $lines.Count
  $hasSummary = ($Text -match '(?im)^(##|###)\s*(summary|conclusion|takeaway)') -or ($Text -match '(?i)\bsummary:\b')

  # Count question-like lines (lines with '?' in a bullet or contains "question")
  $questionLines = $lines | Where-Object { ($_ -match '\?') -or ($_ -match '(?i)\bquestion\b') }
  $numQuestions = $questionLines.Count

  # Simple contradiction heuristic: look for 'not <word>' and '<word>' elsewhere
  $contradictions = @()
  $wordPattern = '\b([a-z]{4,})\b'
  foreach ($line in $lines) {
    if ($line -match '\bnot\s+([a-z]{4,})\b') {
      $w = $Matches[1]
      if ($Text -match "\b$w\b" -and ($line -notmatch "\b$w\b")) {
        $contradictions += @{ word = $w; context = $line }
      }
    }
  }

  $issues = @()
  $score = 100

  if ($lineCount -gt $cfg.MaxLines) {
    $issues += @{ type='verbose'; detail="Thread too long ($lineCount lines)" }
    $score -= $cfg.VerbosePenalty
  }
  if (-not $hasSummary) {
    $issues += @{ type='no-summary'; detail='No explicit Summary/Conclusion section found' }
    $score -= $cfg.NoSummaryPenalty
  }
  if ($numQuestions -ge $cfg.QuestionThreshold) {
    $issues += @{ type='many-questions'; detail="$numQuestions question-like lines" }
    $score -= $cfg.ManyQuestionsPenalty
  }
  if ($contradictions.Count -gt 0) {
    $issues += @{ type='contradiction'; detail = "$($contradictions.Count) potential contradictions" }
    $score -= $cfg.ContradictionPenalty
  }

  if ($score -lt 0) { $score = 0 }

  $result = [PSCustomObject]@{
    Name = $Name
    Score = $score
    Issues = $issues
    Suggestions = @()
    Metadata = [PSCustomObject]@{
      Lines = $lineCount
      Questions = $numQuestions
      HasSummary = $hasSummary
    }
  }

  # Suggestions based on issues
  if ($issues | Where-Object { $_.type -eq 'no-summary' }) {
    $result.Suggestions += 'Add a short (2-4 line) Summary or Conclusion header that captures the final findings.'
  }
  if ($issues | Where-Object { $_.type -eq 'many-questions' }) {
    $result.Suggestions += 'Resolve outstanding questions or mark them clearly; consider splitting sub-questions into separate threads.'
  }
  if ($issues | Where-Object { $_.type -eq 'verbose' }) {
    $result.Suggestions += 'Consider distilling long threads into a short summary and archived details.'
  }
  if ($issues | Where-Object { $_.type -eq 'contradiction' }) {
    $result.Suggestions += 'Review for contradictory statements; add provenance or reconcile conflicting claims.'
  }

  return $result
}

function Scan-ReasoningCorpus {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$false)] [string]$Root = "$PSScriptRoot\..",
    [Parameter(Mandatory=$false)] [switch]$IncludeArchives,
    [Parameter(Mandatory=$false)] [hashtable]$Config = @{}
  )

  $files = @()
  $reasoningFile = Join-Path $Root 'chat_context\reasoning-context.md'
  if (Test-Path $reasoningFile) { $files += $reasoningFile }
  if ($IncludeArchives) {
    $archiveDir = Join-Path $Root 'chat_context\archives'
    if (Test-Path $archiveDir) {
      $files += Get-ChildItem -Path $archiveDir -Filter 'reasoning-archive-*.md' -File | ForEach-Object { $_.FullName }
    }
  }

  $analyses = @()
  foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    # Split into threads by header '## Reasoning Thread: [name]' or top-level '---' separators
    $threadPattern = '(?m)^##\s+Reasoning Thread:\s*\[([^\]]+)\]'
    if ($content -match $threadPattern) {
      $matches = [regex]::Matches($content, $threadPattern)
      $indices = @()
      foreach ($m in $matches) { $indices += @{ Name = $m.Groups[1].Value; Index = $m.Index } }
      # naive splitting: use split on headers
      $parts = [regex]::Split($content, '(?m)^##\s+Reasoning Thread:\s*\[[^\]]+\]')
      # first part is header/template; subsequent parts align with matches
      for ($i = 1; $i -lt $parts.Count; $i++) {
        $name = $matches[$i-1].Groups[1].Value
        $text = $parts[$i].Trim()
        $analyses += Analyze-ReasoningThread -Text $text -Name $name -Config $Config
      }
    } else {
      # Fallback: treat full file as one thread
      $analyses += Analyze-ReasoningThread -Text $content -Name (Split-Path $f -Leaf) -Config $Config
    }
  }

  return $analyses
}

function Write-ReasoningCritiqueReport {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)] [string]$OutDir,
    [Parameter(Mandatory=$true)] [object]$Data
  )

  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
  $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $jsonPath = Join-Path $OutDir "reasoning-critique-$ts.json"
  $mdPath = Join-Path $OutDir "reasoning-critique-$ts.md"

  $Data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

  $md = @()
  $md += "# Reasoning Critique Report - $ts`n"
  foreach ($a in $Data) {
    $md += "## $($a.Name) - Score: $($a.Score)`n"
    if ($a.Issues.Count -gt 0) {
      $md += "**Issues:**`n"
      foreach ($iss in $a.Issues) { $md += "- $($iss.type): $($iss.detail)`n" }
    } else {
      $md += "**Issues:** None`n"
    }
    if ($a.Suggestions.Count -gt 0) {
      $md += "**Suggestions:**`n"
      foreach ($s in $a.Suggestions) { $md += "- $s`n" }
    }
    $md += "`n"
  }

  ($md -join "`n") | Set-Content -LiteralPath $mdPath -Encoding UTF8

  return [PSCustomObject]@{ Json = $jsonPath; Markdown = $mdPath }
}

## When dot-sourced, functions are available; Export-ModuleMember is unnecessary here.
