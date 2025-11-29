<#
.SYNOPSIS
  Policy helpers for chat_context change detection and enforcement.

.DESCRIPTION
  Extracted from scripts/health_check.ps1: Test-ChatContextChangePolicy and
  related helpers are provided here so CI jobs can reuse policy checks.
#>

function Test-ChatContextChangePolicy {
  param(
    [string]$Root
  )

  if (-not $Root) { $Root = (Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path) }
  $gitDir = Join-Path $Root '.git'
  if (-not (Test-Path $gitDir)) { return }

  try {
    Push-Location $Root
    $base = 'origin/main'
    try { git rev-parse --verify $base > $null 2>&1 } catch { $base = 'main' }
    $diffNames = git diff --name-only $base..HEAD 2>$null
    Pop-Location
  } catch {
    Add-Finding -Category 'context' -Severity 'warning' -File $Root `
      -Message "Could not determine git diff for chat_context policy: $($_.Exception.Message)" `
      -Suggestion "Ensure this script runs in a git repo with origin/main fetched before running health_check in CI"
    return
  }

  if (-not $diffNames) { return }

  $changed = $diffNames | Where-Object { $_ -like 'chat_context/*' -or $_ -like 'chat_context\\*' }
  if (-not $changed -or $changed.Count -eq 0) { return }

  $contextDir = Join-Path $Root 'chat_context'
  $changesDir = Join-Path $contextDir 'changes'
  $changesFiles = @()
  if (Test-Path $changesDir) { $changesFiles = Get-ChildItem -Path $changesDir -File -ErrorAction SilentlyContinue }

  $changelogPath = Join-Path $contextDir 'changelog-context.md'
  $changelogText = ''
  if (Test-Path $changelogPath) { $changelogText = Get-Content -Raw -Path $changelogPath -ErrorAction SilentlyContinue }

  $missing = @()
  foreach ($f in $changed) {
    $name = Split-Path $f -Leaf
    $documented = $false
    if ($changelogText -and $changelogText -match [regex]::Escape($name)) { $documented = $true }
    if (-not $documented -and $changesFiles.Count -gt 0) {
      foreach ($cf in $changesFiles) {
        $txt = Get-Content -Raw -Path $cf.FullName -ErrorAction SilentlyContinue
        if ($txt -and $txt -match [regex]::Escape($name)) { $documented = $true; break }
      }
    }
    if (-not $documented) { $missing += $f }
  }

  if ($missing.Count -gt 0) {
    $msg = "Detected changes to chat_context files that lack documentation: $($missing -join ', ')"
    $suggest = "Either add short entries mentioning these files to chat_context/changelog-context.md OR create one or more files under chat_context/changes/ describing the rationale, authors, and reviewer for the change. Use chat_context/changes/CHANGE_TEMPLATE.md as a template."
    Add-Finding -Category 'context' -Severity 'error' -File $changesDir `
      -Message $msg `
      -Suggestion $suggest
  } else {
    Add-Finding -Category 'context' -Severity 'info' -File $changesDir `
      -Message "chat_context changes detected and documented" `
      -Suggestion "Good: context changes included rationale documentation."
  }
}

# end policy.ps1
