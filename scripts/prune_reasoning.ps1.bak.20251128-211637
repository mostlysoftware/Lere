try { Start-RunLog -Root (Resolve-Path -Path ""$PSScriptRoot\.."" | Select-Object -ExpandProperty Path) -ScriptName "prune_reasoning" -Note "auto-applied" } catch { }
. $PSScriptRoot\\lib\\logging.ps1
<#
Prune resolved reasoning threads from reasoning-context.md to reasoning-archive.md.

=== FLOW ===
1. Load shared libraries (Parse-EntryMetadata, Write-Atomically)
2. Read reasoning-context.md and find all ## Reasoning Thread: [name] headers
3. Parse each thread's metadata (unified HTML comments or legacy inference)
4. Determine archive eligibility:
   - Status is 'resolved' (explicit or inferred from Checkpoint section)
   - Last-updated is older than MaxAgeDays
5. Keep the most recent N threads (controlled by -Keep)
6. Archive eligible threads to timestamped file in archives/
7. Rewrite reasoning-context.md with remaining content + archive notice

=== METADATA ===
Uses unified metadata parsing (<!-- metadata --> blocks) with fallback to legacy inference.

A thread is considered archive-eligible if:
  1. Status is 'resolved' (explicit metadata or has Checkpoint section with content)
  2. Last-updated is older than MaxAgeDays

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prune_reasoning.ps1 -Keep 5
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prune_reasoning.ps1 -Keep 5 -MaxAgeDays 14
#>

param(
  [int]$Keep = 5,           # Keep at least N most recent threads in the main file
  [int]$MaxAgeDays = 30,    # Archive threads older than this many days
  [string]$Root = "$PSScriptRoot\.."
)

# Load shared libraries
$libDir = Join-Path $PSScriptRoot 'lib'

$metadataLibPath = Join-Path $libDir 'Parse-EntryMetadata.ps1'
if (Test-Path $metadataLibPath) {
  . $metadataLibPath
  $hasMetadataLib = $true
} else {
  Write-Info "Warning: Metadata library not found at $metadataLibPath; using legacy parsing." -ForegroundColor Yellow
  $hasMetadataLib = $false
}

$writeLibPath = Join-Path $libDir 'Write-Atomically.ps1'
if (Test-Path $writeLibPath) {
  . $writeLibPath
  $hasWriteLib = $true
} else {
  $hasWriteLib = $false
}

$reasoningFile = Join-Path $Root 'chat_context\reasoning-context.md'
$archiveDir = Join-Path $Root 'chat_context\archives'
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$archiveFileName = "reasoning-archive-$timestamp.md"
$archiveFile = Join-Path $archiveDir $archiveFileName

if (-not (Test-Path $reasoningFile)) {
  Write-Error 'reasoning-context.md not found'
  exit 1
}

$content = Get-Content -LiteralPath $reasoningFile -Raw -ErrorAction Stop
$lines = $content -split '\r?\n'

# Find all thread headers: ## Reasoning Thread: [name]
$threadPattern = '^## Reasoning Thread: \[([^\]]+)\]'
$separatorPattern = '^---\s*$'

# Parse into blocks: each thread starts at a header and ends before the next header or separator before next header
$threads = @()
$currentStart = -1
$currentName = ''
$templateEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  if ($line -match $threadPattern) {
    # Save previous thread if exists
    if ($currentStart -ge 0) {
      # Find end: go back from current line to find the preceding ---
      $endIdx = $i - 1
      while ($endIdx -gt $currentStart -and $lines[$endIdx] -match '^\s*$') { $endIdx-- }
      if ($endIdx -gt $currentStart -and $lines[$endIdx] -match $separatorPattern) { $endIdx-- }
      $threads += [PSCustomObject]@{
        Name = $currentName
        Start = $currentStart
        End = $endIdx
        Text = ($lines[$currentStart..$endIdx] -join "`n")
      }
    } else {
      # This is the first real thread; everything before is template/header
      $templateEnd = $i - 1
      # Walk back to find the --- before this thread
      while ($templateEnd -ge 0 -and $lines[$templateEnd] -match '^\s*$') { $templateEnd-- }
    }
    $currentStart = $i
    $currentName = $Matches[1]
  }
}

# Save last thread
if ($currentStart -ge 0) {
  $endIdx = $lines.Count - 1
  while ($endIdx -gt $currentStart -and $lines[$endIdx] -match '^\s*$') { $endIdx-- }
  $threads += [PSCustomObject]@{
    Name = $currentName
    Start = $currentStart
    End = $endIdx
    Text = ($lines[$currentStart..$endIdx] -join "`n")
  }
}

if ($threads.Count -eq 0) {
  Write-Info "No reasoning threads found to prune." -ForegroundColor Green
  exit 0
}

Write-Info "Found $($threads.Count) reasoning threads." -ForegroundColor Cyan

# Determine which threads to archive based on metadata
$now = Get-Date
$cutoffDate = $now.AddDays(-$MaxAgeDays)

foreach ($t in $threads) {
  # Parse metadata (unified or legacy)
  if ($hasMetadataLib) {
    $meta = Parse-EntryMetadata -Text $t.Text
    if (-not $meta.HasMetadata) {
      # Fall back to legacy inference
      $meta = Infer-LegacyMetadata -Text $t.Text -EntryType 'reasoning'
    }
  } else {
    # Manual legacy parsing
    $meta = [PSCustomObject]@{
      Priority = 'low'
      Status = 'open'
      LastUpdated = $null
      Archived = $false
    }
    if ($t.Text -match '\*\*Last updated:\*\*\s*(\d{4}-\d{2}-\d{2})') {
      try { $meta.LastUpdated = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null) } catch { }
    }
    if ($t.Text -match 'Checkpoint.*?\n\s*-\s*\S') { $meta.Status = 'resolved' }
  }
  
  $t | Add-Member -NotePropertyName 'Metadata' -NotePropertyValue $meta -Force
  $t | Add-Member -NotePropertyName 'LastUpdated' -NotePropertyValue $meta.LastUpdated -Force
  $t | Add-Member -NotePropertyName 'IsResolved' -NotePropertyValue ($meta.Status -eq 'resolved') -Force
  $t | Add-Member -NotePropertyName 'IsOld' -NotePropertyValue ($meta.LastUpdated -and ($meta.LastUpdated -lt $cutoffDate)) -Force
}

# Sort by LastUpdated descending (newest first), nulls at end
$sorted = $threads | Sort-Object { if ($_.LastUpdated) { $_.LastUpdated } else { [datetime]::MinValue } } -Descending

# Keep the most recent $Keep threads regardless of status
$toKeep = $sorted | Select-Object -First $Keep
$candidates = $sorted | Select-Object -Skip $Keep

# Archive candidates that are resolved OR old
$toArchive = $candidates | Where-Object { $_.IsResolved -or $_.IsOld }

if ($toArchive.Count -eq 0) {
  Write-Info "No threads eligible for archiving (keeping $Keep most recent; others are not resolved or old enough)." -ForegroundColor Green
  exit 0
}

Write-Info "Archiving $($toArchive.Count) threads..." -ForegroundColor Cyan

. (Join-Path $libDir 'ArchiveDocument.ps1')
$archiveHeader = "# Reasoning Archive`n`nArchived on " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + "`n`n"
$archiveEntries = @()
$archiveEntries += $archiveHeader

foreach ($t in $toArchive) {
  $archiveEntries += "---`n`n"
  $archiveEntries += $t.Text
  $archiveEntries += "`n`n"
}

$archiveResult = Save-ArchiveDocument -ArchiveDir $archiveDir -FileName $archiveFileName -Sections $archiveEntries -MaxRetries 5 -DelayMs 250 -Encoding UTF8

if (-not $archiveResult.Success) {
  Write-Info "Error: Unable to create archive file after 5 attempts: $($archiveResult.Path)" -ForegroundColor Red
  exit 2
}
$archiveFile = $archiveResult.Path

# Rebuild reasoning-context.md: keep template + kept threads + pointers for archived
$archivedNames = $toArchive | ForEach-Object { $_.Name }
$newContent = @()

# Add template/header (everything before first thread)
if ($templateEnd -ge 0) {
  $newContent += ($lines[0..$templateEnd] -join "`n")
}

# Add separator before threads
$newContent += "`n---`n"

# Add kept threads
foreach ($t in $toKeep) {
  $newContent += "`n" + $t.Text + "`n"
  $newContent += "`n---`n"
}

# Add archive pointers for archived threads
if ($toArchive.Count -gt 0) {
  $newContent += "`n## Archived Reasoning Threads`n"
  $newContent += "`nThe following threads have been archived to ``archives/$archiveFileName``:`n"
  foreach ($t in $toArchive) {
    $threadName = $t.Name
    $status = if ($t.IsResolved) { "resolved" } else { "aged out ($MaxAgeDays+ days)" }
    $newContent += "- [#$threadName] -- $status`n"
  }
}

$final = ($newContent -join '').Trim() + "`n"

# Write updated reasoning file
Set-Content -LiteralPath $reasoningFile -Value $final -Encoding UTF8

Write-Info "Pruned $($toArchive.Count) reasoning threads; kept $($toKeep.Count) most recent. Archived to $archiveFile" -ForegroundColor Green

## Compact old reasoning archives via shared helper
. (Join-Path $PSScriptRoot 'lib\ArchiveHelpers.ps1')
Compact-Archives -ArchiveDir $archiveDir -Pattern 'reasoning-archive-*.md' -Keep 10 -Description 'reasoning archives'

exit 0

