<#
.SYNOPSIS
  Install Git hooks from .githooks/ into .git/hooks

.DESCRIPTION
  Copies the repository-maintained hooks from `.githooks/` into the local `.git/hooks`
  directory and ensures a copy for common Windows clients (batch & PowerShell wrappers).

  This script is idempotent and safe to run multiple times.
#>

param()

# Use shared logging helpers
. "$PSScriptRoot\lib\logging.ps1"

$root = (Resolve-Path -Path "$PSScriptRoot\.." -ErrorAction Stop).Path
Push-Location $root
try {
  # initialize per-run log
  Start-RunLog -Root $root -ScriptName 'install_git_hooks' -Note 'Started install_git_hooks'
 
  if (-not (Test-Path (Join-Path $root '.git'))) {
    Write-Err "This does not appear to be a git repository (no .git directory)."
    return 1
  }

  $sourceHooks = Join-Path $root '.githooks'
  if (-not (Test-Path $sourceHooks)) {
    Write-Err ".githooks directory not found; create .githooks/pre-commit first."; return 1
  }

  $destHooks = Join-Path $root '.git\hooks'
  New-Item -ItemType Directory -Path $destHooks -Force | Out-Null

  $copied = 0
  Get-ChildItem -Path $sourceHooks -File | ForEach-Object {
    $src = $_.FullName
    $dest = Join-Path $destHooks $_.Name
    Copy-Item -Path $src -Destination $dest -Force
    # Ensure Unix executable bit on platforms that care (git for windows respects it in MSYS)
    try { & git update-index --add --chmod=+x $dest 2>$null } catch { }
    Write-Info "Installed hook: $($_.Name)"
    $copied++
  }

  # Create a Windows-friendly batch wrapper for pre-commit that invokes PowerShell
  $preCommitBat = Join-Path $destHooks 'pre-commit.bat'
  $batContent = @"
@echo off
for /f "delims=" %%R in ('git rev-parse --show-toplevel') do set REPOROOT=%%R
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPOROOT%\scripts\health_check.ps1" -Scope scripts -Report console
if ERRORLEVEL 1 exit /b 1
exit /b 0
"@
  Set-Content -LiteralPath $preCommitBat -Value $batContent -Force
  Write-Info "Installed Windows wrapper: pre-commit.bat"

  # Create a PowerShell hook wrapper (pre-commit.ps1) for clients that call PowerShell hooks
  $preCommitPs1 = Join-Path $destHooks 'pre-commit.ps1'
  $ps1Content = @"
`$repo = (git rev-parse --show-toplevel)
powershell -NoProfile -ExecutionPolicy Bypass -File "`$repo\scripts\health_check.ps1" -Scope scripts -Report console
if (`$LASTEXITCODE -ne 0) { exit 1 } else { exit 0 }
"@
  Set-Content -LiteralPath $preCommitPs1 -Value $ps1Content -Force
  Write-Info "Installed Windows PowerShell wrapper: pre-commit.ps1"

  # Create Windows-friendly wrappers for pre-push to invoke the build helper
  $prePushBat = Join-Path $destHooks 'pre-push.bat'
  $batPushContent = @"
@echo off
for /f "delims=" %%R in ('git rev-parse --show-toplevel') do set REPOROOT=%%R
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPOROOT%\scripts\dev_setup.ps1" -RunBuild
if ERRORLEVEL 1 exit /b 1
exit /b 0
"@
  Set-Content -LiteralPath $prePushBat -Value $batPushContent -Force
  Write-Info "Installed Windows wrapper: pre-push.bat"

  $prePushPs1 = Join-Path $destHooks 'pre-push.ps1'
  $psPushContent = @"
`$repo = (git rev-parse --show-toplevel)
powershell -NoProfile -ExecutionPolicy Bypass -File "`$repo\scripts\dev_setup.ps1" -RunBuild
if (`$LASTEXITCODE -ne 0) { exit 1 } else { exit 0 }
"@
  Set-Content -LiteralPath $prePushPs1 -Value $psPushContent -Force
  Write-Info "Installed Windows PowerShell wrapper: pre-push.ps1"

  Write-Info "Installed $copied hooks into .git/hooks"
  return 0
} finally {
  try {
    if ($null -ne $global:FirstTimeLogPath -and (Test-Path $global:FirstTimeLogPath)) {
      $summariesDir = Join-Path $root 'chat_context\.summaries'
      if (-not (Test-Path $summariesDir)) { New-Item -ItemType Directory -Path $summariesDir -Force | Out-Null }
      $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
      $copyPath = Join-Path $summariesDir ("install_git_hooks-$ts.log")
      Copy-Item -Path $global:FirstTimeLogPath -Destination $copyPath -Force
      Write-Info "Copied run log into chat_context summaries: $copyPath"
    }
  } catch { }
  Pop-Location
}
