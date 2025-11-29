<#
.SYNOPSIS
  Shared logging helpers for repo PowerShell scripts.

.DESCRIPTION
  Provides Start-RunLog, Save-RunLogToSummaries and Write-Info/Write-Warn/Write-Err helpers
  that append to a per-run log (if initialized) and also write colored console output.

  Scripts should dot-source this file near the top:
    . "$PSScriptRoot\lib\logging.ps1"

  Then call:
    Start-RunLog -Root $root -ScriptName 'install_git_hooks'

#>

function Start-RunLog {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$ScriptName,
        [string]$Note
    )

    try {
        $logDir = Join-Path $Root '.dev\logs'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
        $global:FirstTimeLogPath = Join-Path $logDir ("{0}-{1}.log" -f $ScriptName, $timestamp)
        $startEntry = "$(Get-Date -Format o) [INFO] Started $ScriptName"
        if ($null -ne $Note) { $startEntry += " - $Note" }
        Add-Content -Path $global:FirstTimeLogPath -Value $startEntry
    } catch {
        # best-effort; do not fail callers
    }
}

function Save-RunLogToSummaries {
    param(
        [Parameter(Mandatory=$true)][string]$Root
    )
    try {
        if ($null -ne $global:FirstTimeLogPath -and (Test-Path $global:FirstTimeLogPath)) {
            $summariesDir = Join-Path $Root 'chat_context\.summaries'
            if (-not (Test-Path $summariesDir)) { New-Item -ItemType Directory -Path $summariesDir -Force | Out-Null }
            $leaf = Split-Path $global:FirstTimeLogPath -Leaf
            $copyPath = Join-Path $summariesDir $leaf
            Copy-Item -Path $global:FirstTimeLogPath -Destination $copyPath -Force
            Write-Info "Copied run log into chat_context summaries: $copyPath"
        }
    } catch {
        # swallow to avoid bubbling errors during finalization
    }
}

function Write-Info([string]$m) {
    Write-Host $m -ForegroundColor Cyan
    try { if ($null -ne $global:FirstTimeLogPath) { $entry = "$(Get-Date -Format o) [INFO] $m"; Add-Content -Path $global:FirstTimeLogPath -Value $entry } } catch { }
}
function Write-Warn([string]$m) {
    Write-Host $m -ForegroundColor Yellow
    try { if ($null -ne $global:FirstTimeLogPath) { $entry = "$(Get-Date -Format o) [WARN] $m"; Add-Content -Path $global:FirstTimeLogPath -Value $entry } } catch { }
}
function Write-Err([string]$m) {
    Write-Host $m -ForegroundColor Red
    try { if ($null -ne $global:FirstTimeLogPath) { $entry = "$(Get-Date -Format o) [ERROR] $m"; Add-Content -Path $global:FirstTimeLogPath -Value $entry } } catch { }
}

# end of logging.ps1
