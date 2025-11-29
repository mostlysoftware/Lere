# Refactor: Extract structured RunLog and Checksum helpers

Date: 2025-11-28
Author: automated-refactor

Summary:
- Added `scripts/lib/runlog.ps1` — structured logging facade that builds on `logging.ps1` and writes JSON entries to per-run logs.
- Added `scripts/lib/checksum.ps1` — thin wrapper around `Verify-FileChecksum.ps1` that returns the existing result object and emits structured log entries.
- Dot-sourced the new helpers from `scripts/dev_setup.ps1`, `scripts/first_time_setup.ps1`, and `scripts/health_check.ps1` to make the new API available.

Rationale:
Centralizing the structured log and checksum wrapper makes writing machine-readable run artifacts easier and provides a single place to evolve formats in future (e.g., switching to newline-delimited JSON, additional metadata, or alternative storage).

How to review:
- Ensure no behavior regressions in health-check, dev_setup, or onboarding flows.
- The existing `logging.ps1` and `Verify-FileChecksum.ps1` remain unchanged and continue to work for backwards compatibility.

Backups:
- No files were removed; new files were added and callers were updated to dot-source the wrappers. Existing helpers are still present.

Notes:
- This is an incremental refactor; more callers may be migrated to the structured API in follow-ups.
