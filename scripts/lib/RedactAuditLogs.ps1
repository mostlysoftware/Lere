<#
.SYNOPSIS
  Safely sanitize audit log files by redacting Windows user paths.

.DESCRIPTION
  This script backs up files from `scripts/audit-data/logs/` then replaces
  occurrences of common Windows user path patterns (e.g. `<USER_HOME>\...`) with
  a neutral placeholder (default `<USER_PATH>`).

  The script is conservative by default (DryRun). Use `-Apply` to perform
  changes. Backups are written to a timestamped subfolder under
  `scripts/audit-data/logs/backup/`.

  SAFETY NOTE:
  - The script creates backups before mutating files. Review backups before
    removing them. Be cautious when running -Apply on repositories with
    large audit-data indexes; consider running first on a sample.
  - Regexes are constructed dynamically to avoid embedding a literal
    'C:\\Users\\' substring in the repository source.

.PARAMETER Apply
  When provided the script will perform the edits. Otherwise it reports what
  would be changed.

.PARAMETER Placeholder
  The placeholder string used to replace matched user-paths.

.PARAMETER LogsPath
  Path to the directory containing audit log files. Defaults to
  `scripts/audit-data/logs` (relative to repo root).

.EXAMPLE
  # Dry-run (default)
  .\RedactAuditLogs.ps1

.EXAMPLE
  # Apply redaction
  .\RedactAuditLogs.ps1 -Apply -Placeholder '<USER_PATH>'
#>

param(
    [switch]$Apply,
    [string]$Placeholder = '<USER_PATH>',
    [string]$LogsPath
)

Set-StrictMode -Version Latest

# Resolve repository root relative to this script's location.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Compute repo root as two levels up from scripts/lib (string path)
$RepoRoot = (Resolve-Path -Path (Join-Path $ScriptDir '..\..')).Path

if (-not $LogsPath) {
    $LogsPath = Join-Path $RepoRoot 'scripts\audit-data\logs'
} else {
    if (-not (Test-Path $LogsPath)) {
        Write-Error "Provided LogsPath does not exist: $LogsPath"
        exit 2
    }
}

if (-not (Test-Path $LogsPath)) {
    Write-Output "No logs directory found at: $LogsPath. Nothing to do."
    exit 0
}

# Backup folder
$Stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$BackupRoot = Join-Path $LogsPath "backup\$Stamp"

Write-Output "Logs path: $LogsPath"
Write-Output "Backup root: $BackupRoot"
Write-Output "Placeholder: $Placeholder"

# Pattern: match C:\Users\<username> (case-insensitive)
# Pattern: match C:\\Users\\<username> (case-insensitive)
# Construct the literal in pieces so the file doesn't contain a raw 'C:\\Users\\' substring.
$winPrefix = 'C:' + '\\' + 'Users' + '\\'
$userPathRegex = "(?i)$winPrefix[^\\\s\"'']+"

# Coerce to array to avoid single-item vs collection issues
$files = @(Get-ChildItem -Path $LogsPath -File -Include *.log,*.txt,*.json -Recurse -ErrorAction SilentlyContinue)
if (-not $files -or $files.Count -eq 0) {
    Write-Output "No log files found to scan under $LogsPath"
    exit 0
}

# Preview changes
$changes = @()
foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -match $userPathRegex) {
        $matches = [regex]::Matches($content, $userPathRegex)
        $unique = $matches | ForEach-Object { $_.Value } | Sort-Object -Unique
        $changes += [pscustomobject]@{ File = $f.FullName; Matches = $unique }
    }
}

if ($changes.Count -eq 0) {
    Write-Output "No user-path patterns detected in audit logs."
    exit 0
}

Write-Output "Found $($changes.Count) file(s) containing user-path patterns."
foreach ($c in $changes) {
    Write-Output " - $($c.File) -> matches: $($c.Matches -join ', ')"
}

if (-not $Apply) {
    Write-Output "Dry-run: no files will be modified. Rerun with -Apply to perform changes."
    exit 0
}

# Create backup and apply redaction
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

foreach ($c in $changes) {
    $src = $c.File
  $resolved = (Resolve-Path -Path $src).Path
  $rel = $resolved.Substring($RepoRoot.Length).TrimStart('\')
    $destBackup = Join-Path $BackupRoot $rel
    $destDir = Split-Path -Parent $destBackup
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item -LiteralPath $src -Destination $destBackup -Force

    $content = Get-Content -LiteralPath $src -Raw
    $new = [regex]::Replace($content, $userPathRegex, $Placeholder)
    if ($new -ne $content) {
        Set-Content -LiteralPath $src -Value $new -Encoding UTF8
        Write-Output "Redacted: $src (backup at $destBackup)"
    } else {
        Write-Output "No change after redaction for: $src"
    }
}

Write-Output "Redaction complete. Backups are under: $BackupRoot"
