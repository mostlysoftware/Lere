<#
.SYNOPSIS
  Auto-fix utilities for normalizing console output and inserting run-log calls.

.DESCRIPTION
  Extracted from scripts/health_check.ps1 to provide a reusable autofix API. The
  function `Invoke-SemanticConsoleAutoFix` performs safe, reversible edits and
  creates backups before writing changes.
#>

function Invoke-SemanticConsoleAutoFix {
  param([string]$Path)

  $scripts = Get-ChildItem -Path $Path -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue
  foreach ($s in $scripts) {
    # Skip library and test folders to avoid fragile changes
    if ($s.FullName -match '\\lib\\' -or $s.FullName -match '\\tests\\' -or $s.FullName -match '\\test\\') { continue }
    try {
      $orig = Get-Content -LiteralPath $s.FullName -Raw -ErrorAction Stop
    } catch { continue }

    $modified = $orig
    $changed = $false

    $rel = $s.FullName -replace [regex]::Escape($root), '.'

    if ($modified -match 'Write-Info|Write-Warn|Write-Err' -and $modified -notmatch 'lib\\logging\.ps1') {
      $insert = ". `$PSScriptRoot\\lib\\logging.ps1`n"
      $modified = $insert + $modified
      $changed = $true
      Add-Finding -Category 'console' -Severity 'info' -File $rel -Message "Auto-fixed: dot-sourced lib/logging.ps1" -Suggestion "Added dot-source for shared logging" -Fixed $true
    }

    $lineCount = ($modified -split '\r?\n').Count
    if ($lineCount -gt 80 -and $modified -notmatch 'Start-RunLog\b') {
      $insertion = 'try { Start-RunLog -Root (Resolve-Path -Path ""$PSScriptRoot\.."" | Select-Object -ExpandProperty Path) -ScriptName "' + $s.BaseName + '" -Note "auto-applied" } catch { }' + "`n"
      if ($modified -match 'lib\\logging\.ps1') {
        try {
          $pattern = '(?ms)(^.*?lib\\logging\.ps1.*?\r?\n)'
          $modified = [regex]::Replace($modified, $pattern, { param($m) return $m.Value + $insertion })
        } catch {
          $modified = $insertion + $modified
        }
      } else {
        $modified = $insertion + $modified
      }
      $changed = $true
      Add-Finding -Category 'console' -Severity 'info' -File $rel -Message "Auto-fixed: added Start-RunLog" -Suggestion "Start-RunLog improves traceability" -Fixed $true
    }

    if ($modified -match '\bWrite-Host\b') {
      $modified = $modified -replace '\bWrite-Host\b','Write-Info'
      $changed = $true
      Add-Finding -Category 'console' -Severity 'info' -File $rel -Message "Auto-fixed: replaced Write-Host -> Write-Info" -Fixed $true
    }

    if ($modified -match '\bWrite-Output\b' -or $modified -match '^\s*echo\s') {
      $modified = $modified -replace '\bWrite-Output\b','Write-Info'
      $modified = $modified -replace '(^\s*)echo\s', '$1Write-Info '
      $changed = $true
      Add-Finding -Category 'console' -Severity 'info' -File $rel -Message "Auto-fixed: replaced Write-Output/echo -> Write-Info" -Fixed $true
    }

    if ($changed) {
      try {
        $bak = "$($s.FullName).bak.$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
        Copy-Item -LiteralPath $s.FullName -Destination $bak -Force
        Set-Content -LiteralPath $s.FullName -Value $modified -Encoding UTF8 -Force
        Write-Info "Auto-fixed file: $($s.FullName) (backup: $bak)"
      } catch {
        Add-Finding -Category 'console' -Severity 'warning' -File $rel -Message "Auto-fix failed: $($_.Exception.Message)" -Suggestion "Manual review required"
      }
    }
  }
}

# end autofix.ps1
