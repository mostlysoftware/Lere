<#
run_prune.ps1

Wrapper around `ArchiveManager` that automates proposal creation and (optionally)
creates a draft PR when proposals exceed the review threshold.

Usage examples:
  # dry-run proposal (writes manifest only)
  .\tools\run_prune.ps1 -Paths 'scripts/audit-data/*.json' -RuleId cleanup-old-audit

  # dry-run and attempt to create a draft PR if > threshold (requires gh and remote configured)
  .\tools\run_prune.ps1 -Paths 'scripts/audit-data/*.json' -RuleId cleanup-old-audit -CreatePR

  # apply is allowed only after PR review; Apply without PR is allowed only if --BypassPR is provided
  .\tools\run_prune.ps1 -Paths 'scripts/audit-data/*.json' -RuleId cleanup-old-audit -Apply -BypassPR

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string[]] $Paths,
    [string] $RuleId = 'manual',
    [ValidateSet('low','medium','high')][string] $Risk = 'medium',
    [ValidateSet('low','medium','high')][string] $Impact = 'low',
    [switch] $Apply,
    [switch] $CreatePR,
    [switch] $BypassPR,
    [int] $Threshold,
    [string] $ManifestOutDir = 'scripts/audit-data/manifests',
    [string] $GitRemote = 'origin',
    [string] $BranchPrefix = 'prune'
)

Set-StrictMode -Version Latest

# Load helper scripts
if (Test-Path "scripts/lib/ProjectConfig.ps1") { . .\scripts\lib\ProjectConfig.ps1 }
. .\scripts\lib\ArchiveManager.ps1

# Determine threshold: prefer ProjectConfig if present
if (-not $Threshold) {
    try {
        if ($ProjectConfig -and $ProjectConfig.Prune -and $ProjectConfig.Prune.Threshold) {
            $Threshold = [int]$ProjectConfig.Prune.Threshold
        } else {
            $Threshold = 3
        }
    } catch { $Threshold = 3 }
}

$manifestPath = New-ArchiveProposal -Paths $Paths -ManifestOutDir $ManifestOutDir -RuleId $RuleId -Risk $Risk -Impact $Impact
Write-Host "Proposal manifest: $manifestPath"

$manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
$count = $manifest.Items.Count
Write-Host "Items in proposal: $count (threshold: $Threshold)"

if ($count -le $Threshold) {
    Write-Host "Proposal is below threshold ($Threshold). You may apply locally if desired."
    if ($Apply) {
        Write-Host "Applying proposal..."
        $archiveManifest = Apply-ArchiveManifest -ManifestPath $manifestPath
        Write-Host "Archive manifest: $archiveManifest"
    }
    return
}

# Auto-approve rule: if manifest declares Risk=low and Impact=high and the project config enables auto-approve,
# mark the manifest as Approved = true so operators can apply without an intervening PR if desired.
try {
    if ($manifest.Risk -and $manifest.Impact -and $ProjectConfig.Prune.AutoApproveHighImpactLowRisk) {
        if ($manifest.Risk -eq 'low' -and $manifest.Impact -eq 'high') {
            Write-Host "Manifest meets auto-approve criteria (Risk=low, Impact=high). Marking Approved=true"
            $manifest.Approved = $true
            $tmp = "$manifestPath.tmp"
            $manifest | ConvertTo-Json -Depth 6 | Out-File -FilePath $tmp -Encoding UTF8
            Move-Item -Force -LiteralPath $tmp -Destination $manifestPath
        }
    }
} catch {
    Write-Warning "Auto-approve step failed: $($_.Exception.Message)"
}

# Produce a human-readable markdown summary next to the manifest to make proposals easy to review
try {
    $summaryPath = [System.IO.Path]::ChangeExtension($manifestPath, '.md')
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("# Prune proposal: $RuleId") > $null
    $sb.AppendLine() > $null
    $sb.AppendLine("Generated: $(Get-Date -Format o)") > $null
    $sb.AppendLine() > $null
    $sb.AppendLine("**Items:** $count`)" ) > $null
    $sb.AppendLine() > $null
    $sb.AppendLine("| Path | Length | LastWriteUtc | SHA256 |") > $null
    $sb.AppendLine("| ---- | ------:| ------------- | ------ |") > $null
    foreach ($it in $manifest.Items) {
        $path = $it.Path -replace '\\','/'
        $len = $it.Length
        $lw = $it.LastWriteTimeUtc
        $hash = $it.SHA256
        $sb.AppendLine("| `$path` | $len | $lw | $hash |") > $null
    }
    $sb.ToString() | Out-File -FilePath $summaryPath -Encoding UTF8
    Write-Host "Summary written: $summaryPath"
} catch {
    Write-Warning "Failed to write summary: $($_.Exception.Message)"
}

# Update local index for easy browsing
try {
    . .\scripts\generate_prune_index.ps1 -ManifestsDir $ManifestOutDir
    Write-Host "Updated manifests index"
} catch {
    Write-Warning "Failed to update manifests index: $($_.Exception.Message)"
}

# At this point, the proposal exceeds the threshold and requires review/PR
Write-Host "Proposal exceeds threshold. Preparing PR workflow..."

function New-GitBranchAndCommitManifest($manifestPath, $branchName, $remote) {
    Write-Host "Creating git branch: $branchName"
    & git checkout -b $branchName
    & git add $manifestPath
    & git commit -m "prune proposal: $branchName" --no-verify
    Write-Host "Pushing branch to remote $remote"
    & git push -u $remote $branchName
}

function Create-PrunePR($manifestPath, $ruleId, $branchName) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    $title = "Prune proposal: $ruleId - $branchName"
    $body = "This PR contains a prune proposal. Manifest:\n\n````json\n$(Get-Content -Raw -Path $manifestPath)\n````\n\nPlease review and approve to allow archival."
    if ($gh) {
        Write-Host "Creating draft PR using gh..."
        $prUrl = & gh pr create --title $title --body $body --draft
        Write-Host "PR created: $prUrl"
        return $prUrl
    } else {
        Write-Host "gh CLI not found. Created branch $branchName with manifest committed. Please push and open a draft PR manually."
        return $null
    }
}

$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$branchName = "$BranchPrefix/$ts-$RuleId"

try {
    New-GitBranchAndCommitManifest $manifestPath $branchName $GitRemote
} catch {
    Write-Warning "Git operations failed: $($_.Exception.Message)"
    Write-Host "Please ensure this repository is a git repo with a remote named $GitRemote, or push the manifest manually."
    return
}

$prUrl = $null
if ($CreatePR) { $prUrl = Create-PrunePR $manifestPath $RuleId $branchName }
else { Write-Host "CreatePR not requested; branch created with manifest at $manifestPath" }

if ($Apply) {
    if (-not $BypassPR) {
        Write-Host "Apply requested but PR required. Wait for PR approval and then run Apply-ArchiveManifest using the manifest or archive manifest produced by Apply step."
    } else {
        Write-Host "BypassPR specified. Applying manifest now..."
        $archiveManifest = Apply-ArchiveManifest -ManifestPath $manifestPath
        Write-Host "Archive manifest: $archiveManifest"
    }
}
