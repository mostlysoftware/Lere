<#
.SYNOPSIS
  Helper to print the active ProjectConfig and onboarding hints.

.DESCRIPTION
  Loads scripts/lib/ProjectConfig.ps1 if present and prints a human-friendly
  summary of important thresholds, excludes, and where reports are written.
  Useful for new contributors to quickly discover how to run the health checks
  and where to find outputs.
#>

param()

$cfgPath = Join-Path $PSScriptRoot 'ProjectConfig.ps1'
if (-not (Test-Path $cfgPath)) {
  Write-Host "No ProjectConfig.ps1 found in $PSScriptRoot" -ForegroundColor Yellow
  exit 1
}
. $cfgPath

Write-Host "Project configuration summary" -ForegroundColor Cyan
Write-Host "= Duplicate detection =" -ForegroundColor Green
Write-Host "  MinLines: $($ProjectConfig.Duplicate.MinLines)" -ForegroundColor Gray
Write-Host "  Excludes: $($ProjectConfig.Duplicate.ExcludePaths -join ', ')" -ForegroundColor Gray
Write-Host "  Extensions: $($ProjectConfig.Duplicate.Extensions -join ', ')" -ForegroundColor Gray
Write-Host "  Centralize thresholds: occurrences=$($ProjectConfig.Duplicate.CentralizeOccurrenceThreshold), distinctFiles=$($ProjectConfig.Duplicate.CentralizeDistinctFileThreshold)" -ForegroundColor Gray

Write-Host "= File hygiene =" -ForegroundColor Green
Write-Host "  MaxFileSizeKB: $($ProjectConfig.FileHygiene.MaxFileSizeKB)" -ForegroundColor Gray
Write-Host "  MaxFileLines: $($ProjectConfig.FileHygiene.MaxFileLines)" -ForegroundColor Gray
Write-Host "  Extensions: $($ProjectConfig.FileHygiene.Extensions -join ', ')" -ForegroundColor Gray

Write-Host "= PowerShell =" -ForegroundColor Green
Write-Host "  MaxFunctionLines: $($ProjectConfig.PowerShell.MaxFunctionLines)" -ForegroundColor Gray

Write-Host "= Audit =" -ForegroundColor Green
Write-Host "  Reports written to: $($ProjectConfig.Audit.OutDir)" -ForegroundColor Gray
Write-Host "  Keep recent reports: $($ProjectConfig.Audit.KeepReports)" -ForegroundColor Gray

Write-Host "" -ForegroundColor Gray
Write-Host 'Quick commands for new contributors:' -ForegroundColor Cyan
Write-Host '  Run health check (console): .\scripts\health_check.ps1 -Scope all -Report console' -ForegroundColor Gray
Write-Host '  Run scripts-only checks: .\scripts\health_check.ps1 -Scope scripts -Report console' -ForegroundColor Gray
Write-Host "  View latest duplicates JSON: (Get-ChildItem $($ProjectConfig.Audit.OutDir) -Filter 'duplicates-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName" -ForegroundColor Gray

Write-Host "" -ForegroundColor Gray
Write-Host 'Memory files are under: chat_context - (Memory File) header should be first line of each file.' -ForegroundColor Cyan

Write-Host "" -ForegroundColor Gray
Write-Host 'If you need help, inspect scripts/health_check.ps1 and scripts/lib/ for libraries used by checks.' -ForegroundColor Cyan

exit 0
