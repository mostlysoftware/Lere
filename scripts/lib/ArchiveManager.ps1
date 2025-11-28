<#
ArchiveManager.ps1

Lightweight archival manager for prune/apply workflows.

Functions provided:
- New-ArchiveProposal    : create a dry-run manifest listing files to archive
- Apply-ArchiveManifest  : move files according to a proposal manifest and emit archive manifest
- Restore-FromArchive    : restore files using an archive manifest (verifies SHA256)

Design goals:
- Safe defaults: dry-run required before apply
- Produce atomic manifests for both proposal and archive operations
- Simple, dependency-light (uses built-in PowerShell cmdlets)
#>

function New-ArchiveProposal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string[]] $Paths,
        [Parameter(Mandatory=$true)] [string] $ManifestOutDir,
        [string] $RuleId = 'manual',
        [ValidateSet('low','medium','high')][string] $Risk = 'medium',
        [ValidateSet('low','medium','high')][string] $Impact = 'low',
        [switch] $Force
    )

    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    if (-not (Test-Path $ManifestOutDir)) { New-Item -ItemType Directory -Path $ManifestOutDir -Force | Out-Null }
    $manifestPath = Join-Path $ManifestOutDir "prune-proposal-$timestamp.json"

    $items = @()
    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) { Write-Warning "Path not found: $p"; continue }
        if (Test-Path $p -PathType Container) {
            $files = Get-ChildItem -Path $p -File -Recurse -ErrorAction SilentlyContinue
        } else {
            $files = @(Get-Item -LiteralPath $p)
        }
        foreach ($f in $files) {
            try {
                $h = Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop
                $items += [pscustomobject]@{
                    Path = (Resolve-Path -LiteralPath $f.FullName).Path
                    Length = $f.Length
                    LastWriteTimeUtc = $f.LastWriteTimeUtc
                    SHA256 = $h.Hash
                }
            } catch {
                Write-Warning "Failed to hash: $($f.FullName) - $($_.Exception.Message)"
                $items += [pscustomobject]@{
                    Path = $f.FullName
                    Length = $f.Length
                    LastWriteTimeUtc = $f.LastWriteTimeUtc
                    SHA256 = $null
                    _SkippedReason = $_.Exception.Message
                }
            }
        }
    }

    $manifest = [pscustomobject]@{
        Operator = $env:USERNAME
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        RuleId = $RuleId
        Risk = $Risk
        Impact = $Impact
        Items = $items
        Summary = "Proposal generated: $($items.Count) item(s)"
    }

    $tmp = "$manifestPath.tmp"
    $manifest | ConvertTo-Json -Depth 6 | Out-File -FilePath $tmp -Encoding UTF8
    Move-Item -Force -LiteralPath $tmp -Destination $manifestPath

    Write-Output $manifestPath
}

function Apply-ArchiveManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $ManifestPath,
        [string] $ArchiveRoot = (Join-Path $PSScriptRoot '..\..\scripts\audit-data\archive' | Resolve-Path -ErrorAction SilentlyContinue).Path,
        [string] $SnapshotPath = $null,
        [string] $CiRunId = $null,
        [string] $CiSha = $null,
        [string] $CiRunNumber = $null,
        [switch] $DryRun,
        [switch] $Force
    )

    if (-not (Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
    $proposal = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
    if (-not $ArchiveRoot) { $ArchiveRoot = Join-Path (Get-Location) "scripts\audit-data\archive" }
    $archiveBase = Join-Path $ArchiveRoot $ts
    if ($DryRun) {
        Write-Output "Dry-run: would create archive at $archiveBase (items: $($proposal.Items.Count))"
        return $archiveBase
    }

    New-Item -ItemType Directory -Path $archiveBase -Force | Out-Null

    $moved = @()
    $skipped = @()
    foreach ($it in $proposal.Items) {
        $src = $it.Path
        if (-not (Test-Path $src)) { $skipped += [pscustomobject]@{ Path = $src; Reason = 'Missing' }; continue }
        $rel = Split-Path -Path $src -NoQualifier
        $dest = Join-Path $archiveBase $rel
        $destDir = Split-Path -Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        try {
            Move-Item -LiteralPath $src -Destination $dest -Force
            $moved += [pscustomobject]@{
                OriginalPath = $src
                ArchivePath = (Resolve-Path -LiteralPath $dest).Path
                SHA256 = $it.SHA256
                Length = $it.Length
            }
        } catch {
            $skipped += [pscustomobject]@{ Path = $src; Reason = $_.Exception.Message }
        }
    }

    $archiveManifest = [pscustomobject]@{
        Operator = $env:USERNAME
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        RuleId = $proposal.RuleId
        ArchiveBase = (Resolve-Path -LiteralPath $archiveBase).Path
        OriginalProposal = (Resolve-Path -LiteralPath $ManifestPath).Path
        SnapshotPath = $SnapshotPath
        CiRunId = $CiRunId
        CiSha = $CiSha
        CiRunNumber = $CiRunNumber
        Items = $moved
        Skipped = $skipped
    }

    $archiveManifestPath = Join-Path $archiveBase "archive-manifest-$ts.json"
    $tmp = "$archiveManifestPath.tmp"
    $archiveManifest | ConvertTo-Json -Depth 6 | Out-File -FilePath $tmp -Encoding UTF8
    Move-Item -Force -LiteralPath $tmp -Destination $archiveManifestPath

    Write-Output $archiveManifestPath
}

function Restore-FromArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $ArchiveManifestPath,
        [Parameter(Mandatory=$true)] [string] $OutRoot,
        [switch] $VerifyHash = $true
    )

    if (-not (Test-Path $ArchiveManifestPath)) { throw "Archive manifest not found: $ArchiveManifestPath" }
    $am = Get-Content -Raw -Path $ArchiveManifestPath | ConvertFrom-Json
    foreach ($it in $am.Items) {
        $archivePath = $it.ArchivePath
        if (-not (Test-Path $archivePath)) { Write-Warning "Archived file missing: $archivePath"; continue }
        $rel = Split-Path -Path $archivePath -NoQualifier
        $dest = Join-Path $OutRoot $rel
        $destDir = Split-Path -Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $archivePath -Destination $dest -Force
        if ($VerifyHash -and $it.SHA256) {
            try {
                $h = Get-FileHash -LiteralPath $dest -Algorithm SHA256
                if ($h.Hash -ne $it.SHA256) { throw "Hash mismatch for $($dest)" }
            } catch {
                throw "Verification failed for $($dest): $($_.Exception.Message)"
            }
        }
        Write-Output "Restored: $dest"
    }
}


