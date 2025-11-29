<# Simple smoke test for runlog.ps1 #>
. "$PSScriptRoot\..\lib\runlog.ps1"

try {
  Start-RunLogEx -Root (Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path) -ScriptName 'test_runlog' -Note 'unit-test'
  Write-StructuredLog -Level Info -Message 'RunLog smoke test' -Metadata @{test='runlog'}
  Save-RunLogToSummariesEx -Root (Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path)
  Write-Host 'OK: runlog smoke test'
  exit 0
} catch {
  Write-Host "FAIL: runlog smoke test -> $($_.Exception.Message)"
  exit 2
}
