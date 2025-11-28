<#
.SYNOPSIS
    Rotate older audit-data files into an archive folder while keeping a recent set.

.DESCRIPTION
    Safe helper to archive older reports placed in `scripts/audit-data`. Dry-run by
    default. When Run with -Apply, files older than the most recent KeepReports are
    moved into `scripts/audit-data/archive`.

.PARAMETER DryRun
    When true (default) the script only reports what would be moved.

.PARAMETER Apply
    When provided the script performs the moves.

.PARAMETER Pattern
    Comma-separated patterns (e.g., "*.json,*.md") to match audit files.

.EXAMPLE
    # Dry-run: show what would be archived
    .\AuditRotation.ps1 -DryRun

.EXAMPLE
    # Apply archival
    .\AuditRotation.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$DryRun = $true,
    [switch]$Apply,
    [string]$Pattern = "*.json,*.md"
)

function Invoke-AuditRotation {
    param(
        [string]$RepoRoot,
        [int]$Keep = 10,
        [string[]]$Patterns = @('*.json','*.md'),
        [switch]$DoApply
    )

    $AuditDir = Join-Path $RepoRoot 'scripts\audit-data'
    if (-not (Test-Path $AuditDir)) {
        Write-Output "No audit-data directory found at: $AuditDir";
        return @{Kept=0;Archived=0;ArchivedFiles=@()}
    }

    $ArchiveDir = Join-Path $AuditDir 'archive'
    if (-not (Test-Path $ArchiveDir) -and $DoApply) {
        New-Item -ItemType Directory -Path $ArchiveDir | Out-Null
    }

    $files = @()
    foreach ($p in $Patterns) {
        $files += Get-ChildItem -Path $AuditDir -Filter $p -File -ErrorAction SilentlyContinue
    }

    if (-not $files -or $files.Count -eq 0) {
        Write-Output "No audit files matching patterns ($($Patterns -join ',')) in $AuditDir"
        return @{Kept=0;Archived=0;ArchivedFiles=@()}
    }

    $ordered = $files | Sort-Object LastWriteTime -Descending
    $toKeep = $ordered | Select-Object -First $Keep
    $toArchive = $ordered | Select-Object -Skip $Keep

    Write-Output "Audit rotation: keeping $($toKeep.Count) newest file(s); archiving $($toArchive.Count) older file(s)."

    $archived = @()
    foreach ($f in $toArchive) {
        $src = $f.FullName
        $dest = Join-Path $ArchiveDir $f.Name
        if (-not $DoApply) {
            Write-Output "[DRYRUN] Would move: $src -> $dest"
            $archived += $src
        }
        else {
            Write-Output "Moving: $src -> $dest"
            Move-Item -Path $src -Destination $dest -Force
            $archived += $dest
        }
    }

    return @{Kept=$toKeep.Count;Archived=$toArchive.Count;ArchivedFiles=$archived}
}

# Entrypoint
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
# Repo root is two levels up from scripts/lib -> repo root
$RepoRoot = (Resolve-Path "$ScriptRoot\..\.." | Select-Object -First 1).ProviderPath

$projConfigPath = Join-Path $ScriptRoot 'ProjectConfig.ps1'
if (-not (Test-Path $projConfigPath)) {
    $projConfigPath = Join-Path $RepoRoot 'scripts\lib\ProjectConfig.ps1'
}

if (Test-Path $projConfigPath) { . $projConfigPath }

if (-not (Get-Variable -Name ProjectConfig -ErrorAction SilentlyContinue)) {
    $ProjectConfig = [PSCustomObject]@{ Audit = @{ KeepReports = 10 } }
}

$Keep = $ProjectConfig.Audit.KeepReports
if (-not $Keep -or $Keep -lt 0) { $Keep = 10 }

$patterns = $Pattern -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

$result = Invoke-AuditRotation -RepoRoot $RepoRoot -Keep $Keep -Patterns $patterns -DoApply:$Apply

Write-Output "Result: Kept=$($result.Kept) Archived=$($result.Archived)"
if ($result.ArchivedFiles.Count -gt 0) {
    $result.ArchivedFiles | ForEach-Object { Write-Output "Archived: $_" }
}

if ($Apply) { Write-Output "Audit rotation applied." } else { Write-Output "Dry-run complete. Run with -Apply to perform archival." }
