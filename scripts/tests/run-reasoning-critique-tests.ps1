# Simple test harness for ReasoningCritique functions

$lib = Join-Path $PSScriptRoot '..\lib\ReasoningCritique.ps1'
if (-not (Test-Path $lib)) {
  Write-Host "ReasoningCritique library not found: $lib" -ForegroundColor Red
  exit 2
}
. $lib

$sampleShort = "## Reasoning Thread: [SampleShort]\nThis is a short thread.\nIt has a conclusion.\n## Summary\nConcluded: OK"
$sampleVerboseNoSummary = "## Reasoning Thread: [LongThread]\n" + ("Detail line`n" * 500) + "\nSome open questions?\nAnother question?\nYet another?"

$r1 = Analyze-ReasoningThread -Text $sampleShort -Name 'SampleShort'
if ($r1.Score -lt 80) { Write-Host "SampleShort score too low: $($r1.Score)" -ForegroundColor Red; exit 3 }

$r2 = Analyze-ReasoningThread -Text $sampleVerboseNoSummary -Name 'LongThread'
if ($r2.Metadata.Lines -le 400) { Write-Host "LongThread length detection failed" -ForegroundColor Red; exit 4 }
if (-not ($r2.Issues | Where-Object { $_.type -eq 'no-summary' -or $_.type -eq 'many-questions' })) { Write-Host "LongThread issues not detected" -ForegroundColor Red; exit 5 }

Write-Host "ReasoningCritique tests passed" -ForegroundColor Green
exit 0
