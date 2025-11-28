<#
.SYNOPSIS
  Helpers for compacting archive files (keep most recent N, remove older ones).

.DESCRIPTION
  Provides Compact-Archives which removes older archive files matching a
  given pattern while keeping the most recent N files. Emits informational
  messages and handles errors gracefully.
#>

function Compact-Archives {
  param(
    [Parameter(Mandatory=$true)][string]$ArchiveDir,
    [Parameter(Mandatory=$true)][string]$Pattern,
    [int]$Keep = 10,
    [string]$Description = 'archives'
  )

  if (-not (Test-Path $ArchiveDir)) { return }

  try {
    $archiveFiles = Get-ChildItem -Path $ArchiveDir -Filter $Pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($archiveFiles.Count -gt $Keep) {
      $toRemove = $archiveFiles | Select-Object -Skip $Keep
      foreach ($f in $toRemove) {
        try { Remove-Item -LiteralPath $f.FullName -ErrorAction Stop } catch { Write-Host "Warning: failed to remove old archive $($f.Name)" -ForegroundColor Yellow }
      }
      Write-Host "Compacted $Description: kept $Keep most recent." -ForegroundColor Cyan
    }
  } catch {
    Write-Host "Warning: archive compaction failed: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}
