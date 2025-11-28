<#
Prune old changelog entries from changelog-context.md to changelog-archive.md.

=== FLOW ===
1. Load shared libraries (Write-Atomically)
2. Read changelog-context.md and find all (YYYY-MM-DD, HH:MM) entry markers
3. Parse entry dates from markers
4. Determine archive eligibility:
   - Entry is older than MaxAgeDays
   - High-priority entries (with [#reasoning-thread] refs) get 2x retention
5. Keep the most recent N entries (controlled by -Keep)
6. Archive eligible entries to timestamped file in archives/
7. Rewrite changelog-context.md with remaining content

=== ENTRY FORMAT ===
Entries start with: (YYYY-MM-DD, HH:MM) [description]
High-priority entries contain [#thread-name] references.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prune_changelog.ps1 -Keep 10
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prune_changelog.ps1 -Keep 10 -MaxAgeDays 60
#>

param(
  [int]$Keep = 10,          # Keep at least N most recent entries in the main file
  [int]$MaxAgeDays = 30,    # Archive entries older than this many days
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

$changelogFile = Join-Path $Root 'chat_context\changelog-context.md'
$archiveDir = Join-Path $Root 'chat_context\archives'
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$archiveFileName = "changelog-archive-$timestamp.md"
$archiveFile = Join-Path $archiveDir $archiveFileName

if (-not (Test-Path $changelogFile)) {
  Write-Error 'changelog-context.md not found'
  exit 1
}

$content = Get-Content -LiteralPath $changelogFile -Raw -ErrorAction Stop
$lines = $content -split '\r?\n'

# Find the ## Changes section
$changesStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^## Changes') {
    $changesStart = $i + 1
    break
  }
}

if ($changesStart -lt 0) {
  Write-Host "No '## Changes' section found in changelog-context.md" -ForegroundColor Yellow
  exit 0
}

# Parse changelog entries: - (YYYY-MM-DD, HH:MM) ...
$entryPattern = '^\s*-\s*\((\d{4}-\d{2}-\d{2}),?\s*(\d{2}:\d{2})?\)'
$entries = @()
$now = Get-Date
$cutoffDate = $now.AddDays(-$MaxAgeDays)

for ($i = $changesStart; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  if ($line -match $entryPattern) {
    $dateStr = $Matches[1]
    $timeStr = if ($Matches[2]) { $Matches[2] } else { '00:00' }
    
    $entryDate = $null
    try {
      $entryDate = [datetime]::ParseExact("$dateStr $timeStr", 'yyyy-MM-dd HH:mm', $null)
    } catch {
      try {
        $entryDate = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd', $null)
      } catch { }
    }
    
    # Determine priority: high if references reasoning thread or has [changelog-entry:...]
    $priority = 'low'
    if ($line -match '\[#[^\]]+\]' -or $line -match '\[changelog-entry:') {
      $priority = 'high'
    }
    
    $isOld = $entryDate -and ($entryDate -lt $cutoffDate)
    
    $entries += [PSCustomObject]@{
      LineNum   = $i
      Text      = $line
      Date      = $entryDate
      Priority  = $priority
      IsOld     = $isOld
    }
  }
}

if ($entries.Count -eq 0) {
  Write-Host "No changelog entries found to prune." -ForegroundColor Green
  exit 0
}

Write-Host "Found $($entries.Count) changelog entries." -ForegroundColor Cyan

# Sort by date descending (newest first)
$sorted = $entries | Sort-Object { if ($_.Date) { $_.Date } else { [datetime]::MinValue } } -Descending

# Keep the most recent $Keep entries regardless of age
$toKeep = $sorted | Select-Object -First $Keep
$candidates = $sorted | Select-Object -Skip $Keep

# Archive candidates that are old (high-priority entries get extra retention)
$toArchive = $candidates | Where-Object { 
  if ($_.Priority -eq 'high') {
    # High priority entries get double the retention period
    $_.Date -and ($_.Date -lt $now.AddDays(-($MaxAgeDays * 2)))
  } else {
    $_.IsOld
  }
}

if ($toArchive.Count -eq 0) {
  Write-Host "No entries eligible for archiving (keeping $Keep most recent; others are not old enough)." -ForegroundColor Green
  exit 0
}

Write-Host "Archiving $($toArchive.Count) entries..." -ForegroundColor Cyan

# Ensure archives dir exists
if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }

# Build archive content
$archiveHeader = @"
# Changelog Archive

Archived on $(Get-Date -Format 'yyyy-MM-dd HH:mm')

Entries older than $MaxAgeDays days (high-priority entries retained $($MaxAgeDays * 2) days).

---

## Archived Entries

"@

$archiveEntries = @()
$archiveEntries += $archiveHeader

foreach ($e in ($toArchive | Sort-Object Date -Descending)) {
  $archiveEntries += $e.Text
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

# Rebuild changelog-context.md: keep header + kept entries + archive pointer
$archivedLineNums = $toArchive | ForEach-Object { $_.LineNum }
$newLines = @()

# Add everything before the Changes section
for ($i = 0; $i -lt $changesStart; $i++) {
  $newLines += $lines[$i]
}

# Add kept entries
foreach ($e in ($toKeep | Sort-Object Date -Descending)) {
  $newLines += $e.Text
}

# Add archive pointer
$newLines += ""
$newLines += "---"
$newLines += ""
$newLines += "**Archived entries:** See ``archives/$archiveFileName`` ($($toArchive.Count) entries from before $(($toArchive | Sort-Object Date | Select-Object -First 1).Date.ToString('yyyy-MM-dd')))."

$final = ($newLines -join "`n").TrimEnd() + "`n"

# Write updated changelog
Set-Content -LiteralPath $changelogFile -Value $final -Encoding UTF8 -NoNewline

Write-Host "Pruned $($toArchive.Count) changelog entries; kept $($toKeep.Count) most recent. Archived to $archiveFile" -ForegroundColor Green

## Compact old changelog archives via shared helper
. (Join-Path $PSScriptRoot 'lib\ArchiveHelpers.ps1')
Compact-Archives -ArchiveDir $archiveDir -Pattern 'changelog-archive-*.md' -Keep 10 -Description 'changelog archives'

exit 0
