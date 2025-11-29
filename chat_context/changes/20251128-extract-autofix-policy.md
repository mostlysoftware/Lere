# Refactor: Extract AutoFix and Policy helpers

Date: 2025-11-28
Author: automated-refactor

Summary:
- Added `scripts/lib/autofix.ps1` which contains the `Invoke-SemanticConsoleAutoFix` implementation extracted from `scripts/health_check.ps1`.
- Added `scripts/lib/policy.ps1` which contains `Test-ChatContextChangePolicy` so CI and other scripts may reuse the policy logic.

Rationale:
Centralizing autofix and policy logic makes them reusable by CI workflows and other scripts, and simplifies unit testing.

Review notes:
- The original implementations remain in `scripts/health_check.ps1` in this refactor (no destructive removals). Future steps may move callers to dot-source the library directly.

Backups:
- No files were deleted. New libraries were added and a change note was created for onboarding reviewers.
