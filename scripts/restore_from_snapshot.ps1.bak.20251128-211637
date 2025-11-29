<#
.SYNOPSIS
Restore a single file from a snapshot and verify its hash against the snapshot manifest.

.PARAMETER SnapshotDir
Path to the snapshot folder (e.g. backups/snapshot-YYYYMMDD-HHMMSS)

.PARAMETER RelativePath
Relative path inside the snapshot (for example: scripts/audit-data/duplicates-20251128-053952.json)

.PARAMETER OutDir
Destination directory for the restored file. Defaults to ./restored

.EXAMPLE
  .\scripts\restore_from_snapshot.ps1 -SnapshotDir .\backups\snapshot-20251128-055129 -RelativePath scripts/audit-data/duplicates-20251128-053952.json -OutDir .\restored
#>

param(
  [Parameter(Mandatory=$true)][string]$SnapshotDir,
  [Parameter(Mandatory=$true)][string]$RelativePath,
  [string]$OutDir = 'restored'
)

Set-StrictMode -Version Latest

$manifestPath = Join-Path $SnapshotDir 'manifest.json'
if (-not (Test-Path $manifestPath)) { throw "Manifest not found at: $manifestPath" }

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

# Normalize path separators
$normRel = $RelativePath -replace '/','\'

$entry = $manifest.Items | Where-Object { $_.Path -eq (".\$normRel") }
if (-not $entry) { throw "File not found in manifest: $RelativePath" }

$src = Join-Path $SnapshotDir $RelativePath
if (-not (Test-Path $src)) { throw "Source file missing in snapshot: $src" }

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$dest = Join-Path (Resolve-Path $OutDir).Path (Split-Path -Path $RelativePath -Leaf)
Copy-Item -Path $src -Destination $dest -Force

# Verify hash
try {
  $h = Get-FileHash -Path $dest -Algorithm SHA256
} catch {
  throw "Failed to compute hash for restored file: $($_.Exception.Message)"
}

if ($h.Hash -ne $entry.Hash) {
  Write-Info "WARNING: Restored file hash does not match manifest. Manifest: $($entry.Hash) Restored: $($h.Hash)" -ForegroundColor Yellow
  exit 2
} else {
  Write-Info "Restored and verified: $dest" -ForegroundColor Green
  exit 0
}

