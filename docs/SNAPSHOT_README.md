Snapshot backups

This project creates timestamped snapshots of important repo data (by default: `scripts/audit-data` and `chat_context`) in `backups/`.

How it works

- `scripts/create_snapshot.ps1` copies configured paths into `backups/snapshot-<timestamp>/` and writes `manifest.json` listing files, sizes and SHA256 hashes.
- By default the snapshot manifest includes `Items` (file records) and `Skipped` (files that could not be read during hash or compression).
- Use `-Compress` to create a zip archive adjacent to the snapshot folder. The script will attempt a resilient per-file compression so a locked file won't abort the whole archive; skipped files are recorded.
- Retention is configurable via `scripts/lib/ProjectConfig.ps1` -> `$ProjectConfig.Backup.RetentionDays` (0=keep forever).

Restore

- Use `scripts/restore_from_snapshot.ps1 -SnapshotDir <snapshot-folder> -RelativePath <path-in-snapshot> -OutDir <dest>` to copy a single file out of the snapshot and verify the SHA256 hash against the manifest.

CI

- A GitHub Actions workflow `.github/workflows/snapshot_backups.yml` runs the snapshot daily and uploads the zip artifact. It reads retention days from ProjectConfig and passes it into the snapshot script.

CI auto-apply note

- When the repository config includes a CI auto-apply workflow that performs pruning, that workflow will create a pre-apply snapshot and record the snapshot path and CI run metadata (run id, run number, and commit SHA) in the produced archive manifest. Use those fields to locate the snapshot and the CI run that performed the apply.

Finding the right snapshot

- Archive manifests contain a `SnapshotPath` field which points at the snapshot folder or zip created just before the apply. They also include `CiRunId`, `CiRunNumber`, and `CiSha` when the apply was performed by CI. Use the `CiRunId` / `CiRunNumber` and the repository run log to inspect the exact job and download artifacts if needed.

Notes

- Snapshots are non-destructive and intended as a safety net prior to pruning operations.
- If compression fails for some files (locked), check `manifest.json` -> `Skipped` for details; re-run snapshot at a quieter time if necessary.
- Consider adding offsite encrypted uploads for long-term retention.
