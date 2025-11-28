<#
.SYNOPSIS
Detect files that have been edited multiple times recently to pinpoint potential change loops.

.DESCRIPTION
Scans the last $LookbackCommits commits for repeated modifications on the same paths. If a file appears in more than $Threshold commits, it reports the sequence so you can investigate conflicting directives or automations.

.PARAMETER LookbackCommits
How many recent commits to inspect (default: 20).

.PARAMETER Threshold
Minimum number of distinct commits touching the same file to trigger a warning (default: 2).

.PARAMETER Since
Optional git revision (e.g., HEAD~10) to limit the scan.
#>

param(
  [int]$LookbackCommits = 20,
  [int]$Threshold = 2,
  [string[]]$ExcludePaths = @(),
  [string]$Since = 'HEAD'
)

Set-StrictMode -Version Latest

function Normalize-PathForMatching {
  param([string]$Path)
  if (-not $Path) { return '' }
  $normalized = $Path -replace '\\', '/'
  return $normalized.TrimStart('./')
}

function Path-MatchesPattern {
  param(
    [string]$Value,
    [string]$Pattern
  )

  if (-not $Pattern) { return $false }
  $normalizedValue = Normalize-PathForMatching -Path $Value
  $normalizedPattern = Normalize-PathForMatching -Path $Pattern

  return $normalizedValue -like $normalizedPattern
}

function Should-SkipPath {
  param(
    [string]$Path,
    [string[]]$Patterns
  )

  foreach ($pattern in $Patterns) {
    if (Path-MatchesPattern -Value $Path -Pattern $pattern) { return $true }
  }
  return $false
}

function Parse-GitLog {
  param(
    [string[]]$Lines
  )
  $commits = @()
  $current = $null
  foreach ($line in $Lines) {
    if ($line -match '^commit\s+([0-9a-f]+)') {
      $current = [pscustomobject]@{
        Hash = $Matches[1]
        Files = @()
      }
      $commits += $current
      continue
    }
    $trim = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($trim)) {
      $current.Files += $trim
    }
  }
  return $commits
}

if ($Since) {
  $gitRange = $Since
} else {
  $gitRange = 'HEAD'
}
$gitArgs = @('log', $gitRange, '-n', $LookbackCommits.ToString(), '--name-only', "--pretty=format:commit %H")
$lines = & git @gitArgs 2>$null
if (-not $lines) { Write-Host 'No commits found in the requested range.'; exit 0 }
$commits = Parse-GitLog -Lines $lines

$fileTracking = @{}
for ($index = 0; $index -lt $commits.Count; $index++) {
  $commit = $commits[$index]
  foreach ($path in ($commit.Files | Where-Object { $_ -ne '' })) {
    if (Should-SkipPath -Path $path -Patterns $ExcludePaths) { continue }
    if (-not $fileTracking.ContainsKey($path)) {
      $fileTracking[$path] = @()
    }
    $fileTracking[$path] += [pscustomobject]@{ Commit = $commit.Hash; Order = $index }
  }
}

$results = $fileTracking.GetEnumerator() | Where-Object { $_.Value.Count -ge $Threshold } | Sort-Object -Property Key
if (-not $results) {
  Write-Host 'No recent change loops detected.'
  exit 0
}

Write-Host "Potential change loops detected (files touched ≥ $Threshold times in the last $LookbackCommits commits):" -ForegroundColor Yellow
foreach ($entry in $results) {
  Write-Host "- $($entry.Key):" -ForegroundColor Cyan
  foreach ($record in $entry.Value) {
  Write-Host "    Commit $($record.Commit) (position $($record.Order))"
  }
}

Write-Host "Run this script with a larger --LookbackCommits or inspect the listed commits to find conflicting directives." -ForegroundColor Yellow
