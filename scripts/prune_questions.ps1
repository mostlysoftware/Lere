<#
Prune resolved questions from open-questions-context.md to questions-archive.md.

=== FLOW ===
1. Load shared libraries (Write-Atomically)
2. Read open-questions-context.md
3. Parse questions with inline status metadata: <!-- status: open|resolved|deferred -->
4. Identify resolved questions for archival
5. Archive resolved questions to timestamped file in archives/
6. Rewrite open-questions-context.md with remaining content (open + deferred)

=== STATUS VALUES ===
- open: Active question needing resolution
- deferred: Intentionally postponed; low priority (kept in main file)
- resolved: Answered; eligible for archival

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prune_questions.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prune_questions.ps1 -KeepResolved 5
#>

param(
  [int]$KeepResolved = 0,   # Keep N most recent resolved questions (0 = archive all resolved)
  [string]$Root = "$PSScriptRoot\.."
)

# Load shared libraries
$libDir = Join-Path $PSScriptRoot 'lib'

$writeLibPath = Join-Path $libDir 'Write-Atomically.ps1'
if (Test-Path $writeLibPath) {
  . $writeLibPath
  $hasWriteLib = $true
} else {
  $hasWriteLib = $false
}

$questionsFile = Join-Path $Root 'chat_context\open-questions-context.md'
$archiveDir = Join-Path $Root 'chat_context\archives'
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$archiveFileName = "questions-archive-$timestamp.md"
$archiveFile = Join-Path $archiveDir $archiveFileName

if (-not (Test-Path $questionsFile)) {
  Write-Error 'open-questions-context.md not found'
  exit 1
}

$content = Get-Content -LiteralPath $questionsFile -Raw -ErrorAction Stop
$lines = $content -split '\r?\n'

# Parse questions: lines starting with - that have <!-- status: ... -->
$questionPattern = '^\s*-\s+(.+?)<!--\s*status:\s*(open|resolved|deferred)\s*-->'
$questions = @()
$currentSection = ''

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  
  # Track section headers
  if ($line -match '^##\s+(.+)') {
    $currentSection = $Matches[1].Trim()
    continue
  }
  
  # Match questions with status
  if ($line -match $questionPattern) {
    $questionText = $Matches[1].Trim()
    $status = $Matches[2].ToLower()
    
    $questions += [PSCustomObject]@{
      LineNum  = $i
      Section  = $currentSection
      Text     = $line
      Question = $questionText
      Status   = $status
    }
  }
}

if ($questions.Count -eq 0) {
  Write-Host "No questions with status metadata found." -ForegroundColor Yellow
  exit 0
}

$resolved = $questions | Where-Object { $_.Status -eq 'resolved' }
$open = $questions | Where-Object { $_.Status -eq 'open' }
$deferred = $questions | Where-Object { $_.Status -eq 'deferred' }

Write-Host "Found $($questions.Count) questions: $($open.Count) open, $($resolved.Count) resolved, $($deferred.Count) deferred." -ForegroundColor Cyan

# Archive resolved questions (optionally keep some)
$toArchive = $resolved | Select-Object -Skip $KeepResolved

if ($toArchive.Count -eq 0) {
  Write-Host "No resolved questions to archive." -ForegroundColor Green
  exit 0
}

Write-Host "Archiving $($toArchive.Count) resolved questions..." -ForegroundColor Cyan

# Ensure archives dir exists
if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }

# Build archive content grouped by section
$archiveHeader = @"
# Open Questions Archive

Archived on $(Get-Date -Format 'yyyy-MM-dd HH:mm')

These questions have been resolved and moved from open-questions-context.md.

---

"@

$archiveEntries = @()
$archiveEntries += $archiveHeader

$sections = $toArchive | Group-Object Section
foreach ($sec in $sections) {
  $archiveEntries += "## $($sec.Name)"
  $archiveEntries += ""
  foreach ($q in $sec.Group) {
    $archiveEntries += $q.Text
  }
  $archiveEntries += ""
}

## Write archive atomically via shared writer
. (Join-Path $libDir 'ArchiveWriter.ps1')
$maxRetries = 5
$delayMs = 250
$success = Write-AtomicArchive -Path $archiveFile -Content ($archiveEntries -join "`n") -MaxRetries $maxRetries -DelayMs $delayMs -Encoding UTF8

if (-not $success) {
  Write-Host "Error: Unable to create archive file after $maxRetries attempts: $archiveFile" -ForegroundColor Red
  exit 2
}

# Rebuild open-questions-context.md: remove archived questions
$archivedLineNums = $toArchive | ForEach-Object { $_.LineNum }
$newLines = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($archivedLineNums -contains $i) {
    continue  # Skip archived lines
  }
  $newLines += $lines[$i]
}

# Add archive reference at end
$newLines += ""
$newLines += "---"
$newLines += ""
$newLines += "**Archived questions:** See ``archives/$archiveFileName`` ($($toArchive.Count) resolved questions)."

$final = ($newLines -join "`n").TrimEnd() + "`n"

# Write updated questions file
Set-Content -LiteralPath $questionsFile -Value $final -Encoding UTF8 -NoNewline

Write-Host "Pruned $($toArchive.Count) resolved questions. Archived to $archiveFile" -ForegroundColor Green

## Compact old question archives via shared helper
. (Join-Path $PSScriptRoot 'lib\ArchiveHelpers.ps1')
Compact-Archives -ArchiveDir $archiveDir -Pattern 'questions-archive-*.md' -Keep 10 -Description 'question archives'

# Print summary
Write-Host ""
Write-Host "Remaining questions:" -ForegroundColor White
Write-Host "  Open: $($open.Count)" -ForegroundColor Yellow
Write-Host "  Deferred: $($deferred.Count)" -ForegroundColor Gray
Write-Host "  Resolved (kept): $KeepResolved" -ForegroundColor Green

exit 0
