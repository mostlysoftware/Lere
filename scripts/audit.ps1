# Audit script: finds reasoning-thread hashes, changelog anchors, and session markers
# Performs an orphan check and exits with non-zero if missing targets are found.

$root = Resolve-Path -Path "$PSScriptRoot\.."

Write-Host "Running chat_context audit in $root" -ForegroundColor Cyan

# Gather all markdown files in chat_context
$mdFiles = Get-ChildItem -Path "$root\chat_context" -Recurse -Include *.md | Select-Object -ExpandProperty FullName

function Get-Matches([string[]]$files, [regex]$pattern) {
  $matches = @()
  foreach ($f in $files) {
    $lines = Get-Content -Raw -LiteralPath $f
    foreach ($m in ($pattern.Matches($lines))) {
      $matches += [PSCustomObject]@{ Path = $f; Match = $m.Groups[1].Value }
    }
  }
  return $matches
}

# 1) Reasoning thread references (#[name])
$refPattern = [regex]'\[#([^\]]+)\]'
$refs = Get-Matches -files $mdFiles -pattern $refPattern | Select-Object -ExpandProperty Match -Unique

# Definitions live in reasoning-context.md as headings: ## Reasoning Thread: [name]
$reasoningFile = Join-Path $root 'chat_context\reasoning-context.md'
$defPattern = [regex]'##\s+Reasoning Thread:\s*\[([^\]]+)\]'
$defs = @()
if (Test-Path $reasoningFile) {
  $content = Get-Content -Raw -LiteralPath $reasoningFile
  foreach ($m in ($defPattern.Matches($content))) { $defs += $m.Groups[1].Value }
  $defs = $defs | Sort-Object -Unique
}

$missingReasoning = $refs | Where-Object { $_ -and -not ($defs -contains $_) }

# 2) Changelog anchors
$changelogRefPattern = [regex]'\[changelog-entry:(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]'
$changelogRefs = Get-Matches -files $mdFiles -pattern $changelogRefPattern | Select-Object -ExpandProperty Match -Unique

$changelogFile = Join-Path $root 'chat_context\changelog-context.md'
$changelogDefs = @()
if (Test-Path $changelogFile) {
  $content = Get-Content -Raw -LiteralPath $changelogFile
  foreach ($m in ($changelogRefPattern.Matches($content))) { $changelogDefs += $m.Groups[1].Value }
  $changelogDefs = $changelogDefs | Sort-Object -Unique
}

$missingChangelog = $changelogRefs | Where-Object { $_ -and -not ($changelogDefs -contains $_) }

# 3) Session markers
$sessionRefPattern = [regex]'\(Session (\d{4}-\d{2}-\d{2} \d{2}:\d{2})\)'
$sessionRefs = Get-Matches -files $mdFiles -pattern $sessionRefPattern | Select-Object -ExpandProperty Match -Unique

$sessionFile = Join-Path $root 'chat_context\session-context.md'
$sessionDefs = @()
if (Test-Path $sessionFile) {
  $content = Get-Content -Raw -LiteralPath $sessionFile
  foreach ($m in ($sessionRefPattern.Matches($content))) { $sessionDefs += $m.Groups[1].Value }
  $sessionDefs = $sessionDefs | Sort-Object -Unique
}

$missingSessions = $sessionRefs | Where-Object { $_ -and -not ($sessionDefs -contains $_) }

Write-Host "Audit summary:" -ForegroundColor Cyan
Write-Host "- Reasoning references found: $($refs.Count)" -ForegroundColor Yellow
Write-Host "- Reasoning definitions found: $($defs.Count)" -ForegroundColor Yellow
Write-Host "- Changelog anchors referenced: $($changelogRefs.Count)" -ForegroundColor Yellow
Write-Host "- Changelog anchors defined: $($changelogDefs.Count)" -ForegroundColor Yellow
Write-Host "- Session markers referenced: $($sessionRefs.Count)" -ForegroundColor Yellow
Write-Host "- Session markers defined: $($sessionDefs.Count)" -ForegroundColor Yellow

$hasProblems = $false
if ($missingReasoning.Count -gt 0) {
  Write-Host "\nMissing reasoning thread definitions for the following tags:" -ForegroundColor Red
  $missingReasoning | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($missingChangelog.Count -gt 0) {
  Write-Host "\nMissing changelog anchors referenced in files (not present in changelog-context.md):" -ForegroundColor Red
  $missingChangelog | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($missingSessions.Count -gt 0) {
  Write-Host "\nMissing session markers referenced in files (not present in session-context.md):" -ForegroundColor Red
  $missingSessions | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($hasProblems) {
  Write-Host "\nAudit failed: found missing pointers. Fix the issues or add stubs in the appropriate context files." -ForegroundColor Red
  exit 1
} else {
  Write-Host "\nAudit complete: no missing pointers found." -ForegroundColor Green
  exit 0
}
