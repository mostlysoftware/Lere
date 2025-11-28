# Pruning Policy

This document defines safe, auditable rules for pruning, archiving, and rotating repository content. The goal is to reduce noise while preserving recoverability, traceability, and pointer integrity.

SUMMARY
- Default behavior: pruning operations must run in `dry-run` mode and produce a manifest describing proposed moves before any files are moved or deleted.
- Automatic archival (non-destructive moves to `scripts/audit-data/archive/`) is allowed only after an explicit `Apply` step and review for runs that affect more than `N` files (default N = 3).
- All prune/apply operations must update indexes (SCRIPTS.md / cross-reference index) and be accompanied by a snapshot backup when >N files are moved.

TERMS
- Prune: an operation that removes or archives files from active repository paths.
- Archive: move files into `scripts/audit-data/archive/<timestamp>/` preserving full path and writing a manifest.
- Dry-run: execute pruning logic without moving files; produce a manifest of proposed changes.

POLICY
1. Dry-run required
   - Every pruning action must be run in `--dry-run` (or equivalent) mode by default.
   - The dry-run generates a manifest in `scripts/audit-data/manifests/` named `prune-proposal-<timestamp>.json` containing:
     - Operator (username/CI job), timestamp, rule id, reason, list of files with full path and SHA256, and a short summary of why each file matched.
   - Dry-run manifests are artifacts for reviewers and must be kept with the snapshot for at least the retention window.

2. Thresholds and approvals
   - If a prune proposal affects more than `N` files (default N = 3), the propose step must open a draft PR that:
     - Includes the prune manifest as an artifact or file in the PR,
     - Lists any pointer references found by `audit.ps1` that point to files being pruned,
     - Provides a short checklist confirming that SCRIPTS.md and cross-reference indexes were updated or will be updated,
     - Requests one explicit approver before the `Apply` step.
   - For proposals with ≤ N files, a single operator may `Apply` after a short manual review, but a manifest must still be produced and committed to audit-data.

3. Non-destructive archival and restoreability
   - Pruning must default to archival, not deletion. Files are moved to `scripts/audit-data/archive/<timestamp>/<original-relative-path>`.
   - An archive manifest is created atomically with the move and contains: file path, SHA256, original path, mover identity, datetime, and rule id.
   - A restore helper (`scripts/restore_from_snapshot.ps1`) or `scripts/lib/ArchiveManager.ps1` must be available to perform restores using the manifest.

4. Pointer integrity and automation safety
   - Before applying any prune, run `audit.ps1` or the pointer integrity check. If any pointer references to files to be pruned exist, the prune proposal must mark these and either:
     - Exclude the referenced file from automatic pruning, or
     - Require manual confirmation to allow prune and a plan to update references.
   
8. Auto-approve rule for low-risk / high-impact recommendations
   - In some cases a recommendation is both clearly high-impact (large ROI) and low-risk (no external pointers, non-critical files, or purely derivative docs).
   - When a proposal manifest explicitly sets `Risk = "low"` and `Impact = "high"`, the repository tooling MAY automatically mark the proposal as approved. This behaviour is gated by the configuration value `ProjectConfig.Prune.AutoApproveHighImpactLowRisk` (default: false for safety).
      - Auto-approval does NOT automatically delete or permanently remove files. It simply records `Approved = true` inside the proposal manifest so that operators or automated pipelines that respect the policy can apply the archive without opening a draft PR.
      - Tooling MAY also include a CI-level auto-apply workflow that applies proposals matching this criterion; such CI workflows are considered an operational override and MUST follow the CI rules below (snapshot, manifest upload, commit).
      - The auto-approve rule must only be used where the proposal manifest genuinely reflects the assessment. Tooling that produces recommendations (e.g., automation scanners) should include `Risk`/`Impact` fields in the proposal manifest when appropriate.
      - Exceptions or overrides must be recorded in the PR or in the proposal manifest's `Summary` field.

5. Snapshot & manifest retention
   - At least one snapshot (see `scripts/create_snapshot.ps1`) must be created before applying a multi-file prune (>N). Snapshots are kept per `ProjectConfig.Backup.RetentionDays`.
   - Archive manifests (and prune proposal manifests) should be retained longer than the files (recommended: indefinite) to assist forensics.

6. CI / Automation rules
   - Scheduled/CI pruning runs SHOULD operate in `dry-run` mode and publish the proposal manifest as a CI artifact.
   - Exception: An auditable CI workflow MAY be configured to auto-apply proposals that meet a strict criteria (for example, `Risk = "low"` and `Impact = "high"`). When present, that workflow is allowed to perform the `Apply` step and commit the archive changes back to the repository. Such CI auto-apply workflows MUST:
     - Produce and upload the prune proposal manifest as an artifact before applying.
     - Create a pre-apply snapshot (using `scripts/create_snapshot.ps1`) or ensure a recent snapshot exists and record its path in the archive manifest or CI logs.
     - Write an archive manifest atomically at the time of the move and include operator identity (CI job), timestamp, and the original proposal manifest id.
     - Commit and push any archive and manifest changes so they are auditable in Git history.
     - Log a short summary (manifest id, item count, snapshot id/location) to CI job output.
   - Note: The repository's local tooling default remains conservative (`ProjectConfig.Prune.AutoApproveHighImpactLowRisk = $false`). The presence of a CI auto-apply workflow is an explicit operational decision and should be documented in this policy and in the repository's release notes or admin README.

7. Minimal reviewer checklist (PR body template)
- [ ] Confirm manifest lists all files and includes hashes
- [ ] Confirm pointer audit was run and no unresolved references remain (or document remediation plan)
- [ ] Confirm SCRIPTS.md and cross-reference index updated or will be updated
- [ ] Confirm snapshot was created and available as artifact
- [ ] Approve if no objections

IMPLEMENTATION NOTES
- Use `scripts/create_snapshot.ps1` to create pre-apply snapshots. The CI snapshot workflow runs daily and can be used for one-off snapshots too.
- Keep prune/archival code under `scripts/` and prefer creating small, testable units (e.g., `scripts/lib/ArchiveManager.ps1`) that implement the atomic manifest+move pattern.
- Restore helpers should verify SHA256 against the manifest when restoring; tests (Pester) should cover restore smoke-paths.

GOVERNANCE
- The policy is intentionally conservative; exceptions must be documented in the PR and approved by a reviewer.
- Periodically review retention windows and threshold `N` to strike the right balance between noise reduction and recoverability.

CONTACT
- For questions about pruning policy or to request an emergency restore, open an issue in the repository and tag `@repo-admin` (or your team alias).

Appendix: Example prune workflow
1. Run `.	ools
un_prune.ps1 --dry-run -RuleId cleanup-old-audit` → produces `prune-proposal-2025...json` in `scripts/audit-data/manifests/` and a suggested archive layout.
2. Create draft PR referencing the manifest and request review if >N files.
3. After approval, run `.	ools
un_prune.ps1 --apply -Manifest scripts/audit-data/manifests/prune-proposal-2025...json` to move files and write the final archive manifest.
4. Update `SCRIPTS.md` / cross-reference index as needed and commit those changes in the same PR where possible.
