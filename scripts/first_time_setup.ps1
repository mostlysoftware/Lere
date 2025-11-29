<#
.SYNOPSIS
  First-time repository bootstrap and onboarding helper.

.DESCRIPTION
  Interactive helper to run repository health checks, install git hooks,
  optionally auto-install a local JDK, and trigger initial builds. Creates a
  marker at ./.dev/initialized so it only prompts on first clone. Intended to
  be run once after pulling the repository for the first time.

.PARAMETER NonInteractive
  When set, the script will run with sensible defaults and skip interactive
  prompts where possible.
#>
param(
  [switch]$NonInteractive
)

# Use shared logging helpers
. "$PSScriptRoot\lib\logging.ps1"
. "$PSScriptRoot\lib\runlog.ps1"
. "$PSScriptRoot\lib\checksum.ps1"

$root = Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path
Set-Location -Path $root

# initialize per-run log
Start-RunLog -Root $root -ScriptName 'first_time_setup' -Note 'First-time onboarding helper'

$markerDir = Join-Path $root '.dev'
$markerFile = Join-Path $markerDir 'initialized'

if (-not (Test-Path $markerDir)) { New-Item -ItemType Directory -Path $markerDir -Force | Out-Null }

if (Test-Path $markerFile) {
  Write-Info "Repository already initialized. To re-run first-time actions remove: $markerFile"
  Save-RunLogToSummaries -Root $root
  exit 0
}

Write-Info "Welcome - running first-time setup helper for this repository."
Write-Info "This helper will:" 
Write-Info "  - run the repository health check"
Write-Info "  - offer to install Git hooks"
Write-Info "  - offer to auto-install a local JDK into ./.dev/jdk (optional)"
Write-Info "  - offer to run initial plugin builds"

function Get-YesNo([string]$prompt, [bool]$defaultYes=$true) {
  if ($NonInteractive) { return $defaultYes }
  $suffix = if ($defaultYes) { "[Y/n]" } else { "[y/N]" }
  $r = Read-Host "$prompt $suffix"
  if ([string]::IsNullOrWhiteSpace($r)) { return $defaultYes }
  $c = $r.Trim().ToLower()
  return ($c -eq 'y' -or $c -eq 'yes')
}

$actionsTaken = @()

# Prepare structured report that the AI can read
$report = [ordered]@{
  initializedAt = (Get-Date).ToString('u')
  host = $env:COMPUTERNAME
  os = if ($IsWindows) { 'windows' } elseif (Get-Variable -Name IsLinux -Scope Script -ErrorAction SilentlyContinue) { if ($IsLinux) { 'linux' } else { 'unknown' } } else { 'unknown' }
  actions = @()
}

# Helper to run a child PowerShell process and capture output + exit code
function Invoke-PwshCapture {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )
  $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$FilePath) + $Arguments
  $out = & powershell @argsList 2>&1 | Out-String
  $exit = $LASTEXITCODE
  return [pscustomobject]@{ output = $out; exit = $exit }
}

# 1) Health check
if (Test-Path (Join-Path $root 'scripts\health_check.ps1')) {
  $doHealth = Get-YesNo "Run repository health check now?" $true
  if ($doHealth) {
    Write-Info "Running health check..."
    try {
  $res = Invoke-PwshCapture -FilePath (Join-Path $root 'scripts\health_check.ps1') -Arguments @('-Scope','all')
      $actionsTaken += 'health_check'
      $report.actions += [ordered]@{ name = 'health_check'; success = ($res.exit -eq 0); output = $res.output }
    } catch {
      $err = $_.Exception.Message
      Write-Warn "Health check returned an error: $err"
      $report.actions += [ordered]@{ name = 'health_check'; success = $false; output = $err }
    }
  }
} else {
  Write-Warn "No health_check.ps1 found in scripts/. Skipping."
}

# 2) Install git hooks
if (Test-Path (Join-Path $root 'scripts\setup_hooks.ps1')) {
  $doHooks = Get-YesNo "Install Git hooks (recommended)?" $true
  if ($doHooks) {
    Write-Info "Installing Git hooks..."
    try {
      $res = Invoke-PwshCapture -FilePath (Join-Path $root 'scripts\setup_hooks.ps1') -Arguments @()
      $actionsTaken += 'install_git_hooks'
      $report.actions += [ordered]@{ name = 'install_git_hooks'; success = ($res.exit -eq 0); output = $res.output }
    } catch {
      $err = $_.Exception.Message
      Write-Warn "Hook installation failed: $err"
      Write-Info "You can run: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_hooks.ps1"
      $report.actions += [ordered]@{ name = 'install_git_hooks'; success = $false; output = $err }
    }
  }
} else {
  Write-Warn "No setup_hooks.ps1 found in scripts/. Skipping hook install."
}

# 3) Auto-install JDK (optional)
if (Test-Path (Join-Path $root 'scripts\dev_setup.ps1')) {
  $doJdk = Get-YesNo "Attempt user-local JDK auto-install into ./.dev/jdk? (downloads ~100MB)" $false
  if ($doJdk) {
    Write-Info "Attempting user-local JDK install (may take a few minutes)..."
    try {
      $res = Invoke-PwshCapture -FilePath (Join-Path $root 'scripts\dev_setup.ps1') -Arguments @('-AutoInstallJdk')
      $actionsTaken += 'auto_install_jdk'
      $actionObj = [ordered]@{ name = 'auto_install_jdk'; success = ($res.exit -eq 0); output = $res.output }
      # If the child wrote a verification artifact, include it in the report so the AI can read verification results
      try {
        $vfile = Join-Path $root '.dev\jdk_verification.json'
        if (Test-Path $vfile) {
          $vjson = Get-Content -Path $vfile -Raw | ConvertFrom-Json
          $actionObj.verification = $vjson
        }
      } catch { }
      $report.actions += $actionObj
    } catch {
      $err = $_.Exception.Message
      Write-Warn "Auto JDK install failed: $err"
      Write-Info "You can install a JDK manually (winget/choco) and re-run the dev_setup script."
      $report.actions += [ordered]@{ name = 'auto_install_jdk'; success = $false; output = $err }
    }
  }
} else {
  Write-Warn "No dev_setup.ps1 found in scripts/. Skipping JDK auto-install."
}

# 4) Run local builds
$doBuild = Get-YesNo "Run initial plugin builds now?" $false
if ($doBuild -and (Test-Path (Join-Path $root 'scripts\dev_setup.ps1'))) {
  Write-Info "Running local plugin builds..."
  try {
    $res = Invoke-PwshCapture -FilePath (Join-Path $root 'scripts\dev_setup.ps1') -Arguments @('-RunBuild')
    $actionsTaken += 'run_builds'
    $report.actions += [ordered]@{ name = 'run_builds'; success = ($res.exit -eq 0); output = $res.output }
  } catch {
    $err = $_.Exception.Message
    Write-Warn "Local build step failed: $err"
    $report.actions += [ordered]@{ name = 'run_builds'; success = $false; output = $err }
  }
}

# Write marker with metadata and a richer JSON report the AI can read
$meta = [ordered]@{
  initializedAt = $report.initializedAt
  actions = $actionsTaken
}
try {
  $meta | ConvertTo-Json | Out-File -FilePath $markerFile -Encoding UTF8 -Force
  Write-Info "First-time setup complete. Marker created: $markerFile"

  $reportFile = Join-Path $markerDir 'first_time_report.json'
  $report | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportFile -Encoding UTF8 -Force
  Write-Info "Wrote first-time report: $reportFile"

  # copy a timestamped copy into chat_context/.summaries/ so the AI can read it
  $summariesDir = Join-Path $root 'chat_context\.summaries'
  if (-not (Test-Path $summariesDir)) { New-Item -ItemType Directory -Path $summariesDir -Force | Out-Null }
  $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $copyPath = Join-Path $summariesDir "first_time_report-$ts.json"
  Copy-Item -Path $reportFile -Destination $copyPath -Force
  Write-Info "Copied report into chat_context summaries: $copyPath"

} catch {
  Write-Warn "Failed to write marker or report file: $($_.Exception.Message)"
}
Write-Info 'The first-time report is available at ./.dev/first_time_report.json and in chat_context/.summaries/.'
Write-Info 'Paste the contents into the AI assistant or ask: "Process my first-time report".'

Save-RunLogToSummaries -Root $root

exit 0

