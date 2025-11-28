# ArchiveManager — quick reference

Purpose
-------
A tiny, dependency-light helper that implements a safe pruning/archive workflow for repository files. It provides three main functions meant to be dot-sourced from PowerShell:

- `New-ArchiveProposal` — produce a dry-run manifest listing files to archive (with SHA256 hashes when possible).
- `Apply-ArchiveManifest` — move files listed in a proposal into `scripts/audit-data/archive/<timestamp>/` and write an archive manifest.
- `Restore-FromArchive` — restore archived files using an archive manifest and verify SHA256.

Contract (inputs / outputs / error modes)
---------------------------------------
- Inputs:
  - Paths (files or folders) for `New-ArchiveProposal`.
  - Manifest path for `Apply-ArchiveManifest` (output of `New-ArchiveProposal`).
  - Archive manifest path + OutRoot for `Restore-FromArchive`.
- Outputs:
  - Proposal manifests: `scripts/audit-data/manifests/prune-proposal-<timestamp>.json`.
  - Archive manifests: `scripts/audit-data/archive/<timestamp>/archive-manifest-<timestamp>.json`.
  - Console messages describing dry-run vs. applied moves.
- Error / edge cases:
  - Files that cannot be hashed are included with a null SHA256 and a skipped reason.
  - Missing files at Apply time are recorded in the `Skipped` array of the archive manifest.
  - `Apply-ArchiveManifest` is non-reversible unless you use the archive manifest with `Restore-FromArchive`.

Quick usage
-----------
Dot-source the script first (from repo root):

```powershell
. .\scripts\lib\ArchiveManager.ps1
```

Create a dry-run proposal for a path (example):

```powershell
$proposal = New-ArchiveProposal -Paths 'scripts/audit-data/*.json' -ManifestOutDir 'scripts/audit-data/manifests' -RuleId 'cleanup-old-audit'
Write-Host "Proposal written: $proposal"
```

Review the generated proposal JSON in `scripts/audit-data/manifests/` before applying.

Apply the proposal (dry-run):

```powershell
Apply-ArchiveManifest -ManifestPath $proposal -DryRun
```

Apply (perform the move):

```powershell
Apply-ArchiveManifest -ManifestPath $proposal
```

Restore a file or whole archive (verifies SHA256 when available):

```powershell
Restore-FromArchive -ArchiveManifestPath 'scripts/audit-data/archive/20251128-123456/archive-manifest-20251128-123456.json' -OutRoot 'restored'
```

CI / automation snippet (dry-run proposal + upload manifest)
---------------------------------------------------------
In CI (or scheduled job) you should *only* run the dry-run step and publish the proposal manifest as an artifact for human review. Example (simplified):

```powershell
. .\scripts\lib\ArchiveManager.ps1
$proposal = New-ArchiveProposal -Paths 'scripts/audit-data/*.json' -ManifestOutDir 'scripts/audit-data/manifests' -RuleId 'ci-dryrun'
Write-Host "::notice::Proposal created at $proposal"
# Upload $proposal as CI artifact (platform-specific)
```

Notes and best practices
------------------------
- Always run `New-ArchiveProposal` (dry-run) first and keep the proposal manifest alongside snapshots.
- For proposals affecting more than the policy threshold `N` (see `docs/PRUNING_POLICY.md`), open a draft PR including the proposal manifest and request review before running `Apply-ArchiveManifest`.
- The scripts produce JSON manifests using atomic write (temp file + Move-Item) — treat these as audit artifacts.
- Restore operations verify SHA256 when present; keep manifests and snapshots for at least the retention window configured in `scripts/lib/ProjectConfig.ps1`.

Limitations
-----------
- The manager intentionally keeps scope narrow: it does not compress archives, perform encryption, or push archives offsite.
- On Windows, some path normalization choices may result in long path behavior; handle long paths with appropriate platform settings if needed.

If you want more
---------------
- I can add a small wrapper `tools/run_prune.ps1` that implements a simple CLI around these functions, including automatic PR creation when >N files are proposed, and a GitHub Actions workflow to publish the proposal manifest as an artifact. Tell me which you'd like next.
