<#
.SYNOPSIS
  Helper to push the current branch to origin. Intended for use by local git hooks.
#>
param()

try {
  Push-Location (git rev-parse --show-toplevel | ForEach-Object { $_.Trim() })
} catch {
  # If git rev-parse fails, fall back to script root
  Push-Location $PSScriptRoot
}

Write-Output "Autopush: pushing HEAD to origin..."
try {
  $out = git push origin HEAD 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Output "Autopush: push succeeded"
    Write-Output $out
    Pop-Location
    exit 0
  } else {
    Write-Output "Autopush: push failed (exit $LASTEXITCODE)"
    Write-Output $out
    Pop-Location
    exit $LASTEXITCODE
  }
} catch {
  Write-Output "Autopush: exception: $($_.Exception.Message)"
  Pop-Location
  exit 2
}
