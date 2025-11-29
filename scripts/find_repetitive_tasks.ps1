<#
.SYNOPSIS
Detect repeated manual tasks (documentation code blocks, TODOs, repeated script sequences) and surface low-risk automation opportunities.

.DESCRIPTION
Scans repository markdown and PowerShell script files for repeated fenced code blocks, identical TODO/FIXME lines, and repeated multi-line sequences in .ps1 files. Produces a JSON report listing candidates with a simple risk heuristic:
- low: purely documentation duplicates (docs only)
- medium: duplicates appear in `scripts/` (good candidates for helper scripts)
- high: duplicates appear in `plugins/` or other code (recommend human review)

The report is written atomically to `scripts/audit-data/automation-opportunities-<timestamp>.json`.

.PARAMETER Root
Repository root (defaults to inferred parent of this script)

.EXAMPLE
.
  .\scripts\find_repetitive_tasks.ps1 -Root .. -Force
#>

param(
  [string]$Root = (Resolve-Path -Path (Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath '..')).Path,
  [switch]$Force
)

Set-StrictMode -Version Latest

# Use shared logging helpers
. "$PSScriptRoot\lib\logging.ps1"

$rootPath = Resolve-Path -LiteralPath $Root -ErrorAction Stop
Start-RunLog -Root $rootPath.Path -ScriptName 'find_repetitive_tasks' -Note 'Find repetitive tasks'

function Write-JsonAtomic($obj, $outPath) {
  $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetFileName($outPath) + ".tmp.$([System.Diagnostics.Process]::GetCurrentProcess().Id)")
  $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $tmp -Encoding UTF8 -Force
  Move-Item -Path $tmp -Destination $outPath -Force
}

$rootPath = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$mdFiles = Get-ChildItem -Path $rootPath -Recurse -File -Include *.md -ErrorAction SilentlyContinue
$psFiles = Get-ChildItem -Path $rootPath -Recurse -File -Include *.ps1 -ErrorAction SilentlyContinue

# 1) Extract fenced code blocks from markdown files and count identical blocks
$codeBlockCounts = @{}
foreach ($f in $mdFiles) {
  $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  $pattern = '(?ms)```(?:[a-zA-Z0-9+-]*)?\s*(.*?)```'
  $matches = [regex]::Matches($text, $pattern)
  foreach ($m in $matches) {
    $code = $m.Groups[1].Value.Trim() -replace '\r?\n\s*', "\n"
  $norm = ($code -replace '\s+',' ').Trim()
    if ($norm.Length -lt 5) { continue }
    $key = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($norm))
    if (-not $codeBlockCounts.ContainsKey($key)) { $codeBlockCounts[$key] = @{ Count = 0; Examples = @(); Files = @() } }
    $codeBlockCounts[$key].Count++
    if ($codeBlockCounts[$key].Examples.Count -lt 3) { $codeBlockCounts[$key].Examples += $norm }
    if ($codeBlockCounts[$key].Files -notcontains $f.FullName) { $codeBlockCounts[$key].Files += $f.FullName }
  }
}

# 2) Find repeated TODO/FIXME lines across files
$todoCounts = @{}
$todoPattern = '(?m)^\s*#\s*(TODO|FIXME|HACK|XXX)[:\s]*(.+)$'
foreach ($f in ($mdFiles + $psFiles)) {
  $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
  if (-not $lines) { continue }
  foreach ($line in $lines) {
    if ($line -match $todoPattern) {
      $text = $Matches[2].Trim()
      if ($text.Length -lt 5) { continue }
      if (-not $todoCounts.ContainsKey($text)) { $todoCounts[$text] = @{ Count = 0; Files = @() } }
      $todoCounts[$text].Count++
      if ($todoCounts[$text].Files -notcontains $f.FullName) { $todoCounts[$text].Files += $f.FullName }
    }
  }
}

# 3) Slide window across PS1 files to find repeated multi-line sequences (3+ lines)
$seqCounts = @{}
foreach ($f in $psFiles) {
  $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
  if (-not $lines) { continue }
  $clean = $lines | Where-Object { $_ -notmatch '^\s*$' } # drop blank lines
  for ($i=0; $i -le $clean.Count - 3; $i++) {
    $seq = ($clean[$i..($i+2)] -join "\n") -replace '\s+',' '
    if ($seq.Length -lt 20) { continue }
    $key = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($seq))
    if (-not $seqCounts.ContainsKey($key)) { $seqCounts[$key] = @{ Count = 0; Examples = @(); Files = @() } }
    $seqCounts[$key].Count++
    if ($seqCounts[$key].Files -notcontains $f.FullName) { $seqCounts[$key].Files += $f.FullName }
    if ($seqCounts[$key].Examples.Count -lt 2) { $seqCounts[$key].Examples += $seq }
  }
}

# Build suggestions
$suggestions = @()

foreach ($k in $codeBlockCounts.Keys) {
  $entry = $codeBlockCounts[$k]
  if ($entry.Count -gt 1) {
    # Determine risk: docs-only => low; if any file path under scripts/ => medium
    $risk = 'low'
    foreach ($p in $entry.Files) { if ($p -match '\\scripts\\') { $risk = 'medium'; break } if ($p -match '\\plugins\\') { $risk = 'high'; break } }
    $suggestions += [PSCustomObject]@{
      Type = 'doc-code-block'
      Count = $entry.Count
      Risk = $risk
      Files = $entry.Files
      Examples = $entry.Examples
      Recommendation = if ($risk -eq 'low') { 'Consider moving this command snippet into a single helper script and reference it from docs.' } elseif ($risk -eq 'medium') { 'Consider creating a shared helper under scripts/ and replacing repeated blocks with a single script call.' } else { 'Review for possible library extraction; requires manual review.' }
    }
  }
}

foreach ($t in $todoCounts.Keys) {
  $e = $todoCounts[$t]
  if ($e.Count -gt 2) {
    $risk = 'low'
    foreach ($p in $e.Files) { if ($p -match '\\scripts\\' -or $p -match '\\plugins\\') { $risk = 'medium'; break } }
    $suggestions += [PSCustomObject]@{
      Type = 'todo'
      Text = $t
      Count = $e.Count
      Risk = $risk
      Files = $e.Files
      Recommendation = 'If this is truly repetitive, consider automating or creating a checklist/task in the project board. Start with a small script to address the TODO.'
    }
  }
}

foreach ($k in $seqCounts.Keys) {
  $e = $seqCounts[$k]
  if ($e.Count -gt 1) {
    $risk = 'medium'
    foreach ($p in $e.Files) { if ($p -match '\\plugins\\') { $risk = 'high'; break } }
    $suggestions += [PSCustomObject]@{
      Type = 'script-sequence'
      Count = $e.Count
      Risk = $risk
      Files = $e.Files
      Examples = $e.Examples
      Recommendation = if ($risk -eq 'medium') { 'Consider refactoring into a shared function in scripts/lib.' } else { 'Manual review recommended before extracting.' }
    }
  }
}

$outDir = Join-Path $rootPath 'scripts\audit-data'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = Join-Path $outDir ("automation-opportunities-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))

$report = [PSCustomObject]@{
  Timestamp = (Get-Date).ToString('o')
  Root = $rootPath.Path
  Suggestions = $suggestions | Sort-Object @{Expression = { switch ($_.Risk) { 'low' {0} 'medium' {1} 'high' {2} } } }, @{Expression = 'Count'; Descending = $true }
}

Write-JsonAtomic $report $outFile
Write-Info $outFile

try { Save-RunLogToSummaries -Root $rootPath.Path } catch { }

exit 0

