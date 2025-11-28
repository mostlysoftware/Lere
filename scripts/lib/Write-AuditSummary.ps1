<#
.SYNOPSIS
Write a human-readable audit summary markdown file from an archive manifest.

.DESCRIPTION
Reads an archive manifest JSON file and emits a compact markdown summary suitable for quick review and committing to the repo.

.PARAMETER ArchiveManifestPath
Path to the archive-manifest-*.json produced by Apply-ArchiveManifest.

.PARAMETER OutDir
Directory to write the summary file into. Defaults to the manifest's directory.

.OUTPUTS
Path to the generated markdown summary.
#>

param(
  [Parameter(Mandatory=$true)] [string] $ArchiveManifestPath,
  [string] $OutDir = $null
)

Set-StrictMode -Version Latest

if (-not (Test-Path $ArchiveManifestPath)) { throw "Archive manifest not found: $ArchiveManifestPath" }
$am = Get-Content -Raw -Path $ArchiveManifestPath | ConvertFrom-Json
$manifestDir = Split-Path -Path $ArchiveManifestPath -Parent
if (-not $OutDir) { $OutDir = $manifestDir }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$base = [System.IO.Path]::GetFileNameWithoutExtension($ArchiveManifestPath)
$summaryPath = Join-Path $OutDir ("$base.md")

$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("# Archive summary: $base") > $null
$sb.AppendLine() > $null
$sb.AppendLine("Generated: $(Get-Date -Format o)") > $null
$sb.AppendLine() > $null
$sb.AppendLine("- Operator: $($am.Operator)") > $null
$sb.AppendLine("- Timestamp: $($am.Timestamp)") > $null
if ($am.RuleId) { $sb.AppendLine("- RuleId: $($am.RuleId)") > $null }
if ($am.OriginalProposal) { $sb.AppendLine("- OriginalProposal: $($am.OriginalProposal)") > $null }
if ($am.SnapshotPath) { $sb.AppendLine("- SnapshotPath: $($am.SnapshotPath)") > $null }
if ($am.CiRunId) { $sb.AppendLine("- CiRunId: $($am.CiRunId)") > $null }
if ($am.CiRunNumber) { $sb.AppendLine("- CiRunNumber: $($am.CiRunNumber)") > $null }
if ($am.CiSha) { $sb.AppendLine("- CiSha: $($am.CiSha)") > $null }
$sb.AppendLine() > $null
$sb.AppendLine("**Items archived:** $($am.Items.Count)`") > $null
$sb.AppendLine() > $null
$sb.AppendLine("| OriginalPath | ArchivePath | Length | SHA256 |") > $null
$sb.AppendLine("| --- | --- | ---: | --- |") > $null
foreach ($it in $am.Items) {
    $orig = $it.OriginalPath -replace '\\','/'
    $arch = $it.ArchivePath -replace '\\','/'
    $len = $it.Length
    $sha = $it.SHA256
    $sb.AppendLine("| `$orig` | `$arch` | $len | `$sha` |") > $null
}

$sb.ToString() | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Output $summaryPath
