<#
.SYNOPSIS
  Scan repository text files to find duplicated blocks of consecutive lines (copy-paste).

.DESCRIPTION
  Produces a JSON report and console summary of duplicated blocks across files. Designed
  to help identify copy/paste or large repeated content that should be consolidated or
  refactored for smaller LLM consumption.

.PARAMETER RootPath
  Root path of the repository. Defaults to current directory.

.PARAMETER IncludePaths
  Relative subpaths under RootPath to scan (array). Defaults to 'chat_context'.

.PARAMETER MinLines
  Minimum number of consecutive lines to consider a block for duplication. Default 5.

.PARAMETER Extensions
  File extensions to include (array). Defaults to .md, .ps1, .txt.

.EXAMPLE
  .\scan_duplicates.ps1 -RootPath C:\repo -IncludePaths chat_context,scripts -MinLines 5 -Extensions .md,.ps1
#>

param(
  [string]$RootPath = (Get-Location).ProviderPath,
  [string[]]$IncludePaths = @('chat_context'),
  [int]$MinLines = 5,
  [string[]]$Extensions = @('.md', '.ps1', '.txt'),
  [string[]]$ExcludePaths = @()
)

# Allow a single comma-separated argument to be passed from command-line.
if ($IncludePaths -and $IncludePaths.Count -eq 1 -and $IncludePaths[0] -like '*,*') {
  $IncludePaths = $IncludePaths[0] -split '\s*,\s*'
}
if ($Extensions -and $Extensions.Count -eq 1 -and $Extensions[0] -like '*,*') {
  $Extensions = $Extensions[0] -split '\s*,\s*'
}

# Load the shared duplicate detection library
try {
  . (Join-Path $PSScriptRoot 'lib\DuplicateContent.ps1')
} catch {
  Write-Error "Failed to load DuplicateContent library: $($_.Exception.Message)"
  exit 2
}

Write-Host "Duplicate scanner starting. Root: $RootPath" -ForegroundColor Cyan

$dups = $null
try {
  $dups = Get-DuplicateBlocks -RootPath $RootPath -IncludePaths $IncludePaths -MinLines $MinLines -Extensions $Extensions -ExcludePaths $ExcludePaths
} catch {
  Write-Error "Get-DuplicateBlocks failed: $($_.Exception.Message)"
}

$outDir = Join-Path -Path $RootPath -ChildPath 'scripts\audit-data'

if ($null -ne $dups) {
  try {
    $outJson = Write-DuplicateReport -Duplicates $dups -OutDir $outDir -Prefix 'duplicates'
    Write-Host "Scan complete. Found $($dups.Count) duplicated block(s). Report: $outJson" -ForegroundColor Green
  } catch {
    Write-Error "Failed to write duplicates report: $($_.Exception.Message)"
  }
} else {
  Write-Host "No duplicates data returned by Get-DuplicateBlocks; nothing to report." -ForegroundColor Yellow
}

if ($dups -and $dups.Count -gt 0) {
  foreach ($d in $dups) {
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host "Hash: $($d.Hash)  Count: $($d.Count)" -ForegroundColor Cyan
    Write-Host "Sample (first instance):" -ForegroundColor Gray
    $sampleLines = $d.Sample -split "`n"
    $sampleLines[0..([Math]::Min($sampleLines.Count - 1, 20))] | ForEach-Object { Write-Host "  $_" }
    Write-Host "Instances:" -ForegroundColor Gray
    foreach ($inst in $d.Instances) {
      Write-Host "  $($inst.File) : line $($inst.Line)" -ForegroundColor Yellow
    }
  }
}

Write-Host "Duplicate scanner finished." -ForegroundColor Cyan

