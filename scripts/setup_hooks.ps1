<#
.SYNOPSIS
  Windows-friendly wrapper to set git core.hooksPath to `.githooks` and run the hook installer.

.DESCRIPTION
  On Windows PowerShell (v5.1) the '&&' operator is not available. This helper runs the
  equivalent steps in a single PowerShell script so you don't need to chain commands in the shell.

  Usage (from repo root):
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_hooks.ps1
#>

try {
  # Load shared logging helpers and initialize per-run log
  . "$PSScriptRoot\lib\logging.ps1"
  $scriptRoot = Resolve-Path -Path "$PSScriptRoot" -ErrorAction Stop | Select-Object -ExpandProperty Path
  Push-Location -Path (Resolve-Path -Path "$scriptRoot\.." -ErrorAction Stop)
  Start-RunLog -Root $scriptRoot -ScriptName 'setup_hooks' -Note 'Setting hooksPath and installing hooks'

  Write-Info "Setting git core.hooksPath to .githooks"
  git config core.hooksPath .githooks

  Write-Info "Running hook installer: scripts/install_git_hooks.ps1"
  # Invoke installer script directly rather than spawning a new powershell process
  $installer = Join-Path $scriptRoot 'install_git_hooks.ps1'
  if (-not (Test-Path $installer)) {
    Write-Err "Installer not found: $installer"
    exit 2
  }

  & $installer
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    Write-Err "install_git_hooks.ps1 exited with code $code"
    exit $code
  }

  Write-Info "Hooks installed and core.hooksPath configured."
  exit 0
} catch {
  Write-Err "Setup failed: $($_.Exception.Message)"
  exit 1
} finally {
  try { Save-RunLogToSummaries -Root $scriptRoot } catch { }
  Pop-Location -ErrorAction SilentlyContinue
}
