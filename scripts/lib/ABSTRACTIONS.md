Design: Standardized abstractions for repository tooling

Goal
----
Define small, stable contracts for reusable features used by health checks and onboarding so callers can depend on consistent inputs/outputs and tests can validate behavior.

Components & Contracts
----------------------
1) RunLog / Logging
- Purpose: Structured, machine-readable run logs while retaining colored console output for humans.
- API (facade):
  - Start-RunLogEx -Root <path> -ScriptName <string> -Note <string?>
  - Write-StructuredLog -Level (Info|Warn|Error) -Message <string> -Metadata <hashtable?>
  - Save-RunLogToSummariesEx -Root <path>
- Inputs: Root repo path, short script name, message string, optional metadata hashtable.
- Outputs: Writes human-friendly console output; appends structured JSON entries to a per-run log file; returns success/fail implicitly (exceptions swallowed by design).
- Error modes: disk write failure, missing Root → functions should swallow where possible and return non-fatal status.
- Edge cases: concurrent runs writing same filename (use timestamp/pid-suffix); non-UTF8 characters in messages; CI environments where console coloring is captured differently.

2) Checksum/Verification
- Purpose: Compute and verify checksums (sha256) for downloaded artifacts.
- API:
  - Verify-FileChecksumEx -FilePath <path> -ExpectedChecksum <hex?> -ManifestUrl <url?> → PSCustomObject { Verified, Expected, Computed, Algorithm, Message }
- Inputs: file path, expected checksum or a manifest URL to fetch expected checksum from.
- Outputs: Detailed result object; also emits a structured log entry via RunLog facade when available.
- Error modes: missing file, network/manifest fetch errors, unsupported algorithm.
- Edge cases: very large files (streaming), manifest formats with extra text/filenames, newline/trailing whitespace in checksum files.

3) JDK Installer (local-first)
- Purpose: Install or reuse a user-local JDK under ./.dev/jdk with checksum verification where available.
- API:
  - Install-TemurinJdk -Version <string> -Root <path> -ForceJdk -SkipChecksum → boolean or result object
- Inputs: requested major version (e.g., 17), repository root, flags for forcing re-install and skipping checksum.
- Outputs: boolean success; writes `.dev/jdk_verification.json` when verification performed.
- Error modes: network unreachable, checksum mismatch, unsupported OS/arch.
- Edge cases: partial downloads, permission failures when writing to ./.dev, multiple JDK variants inside extracted archive (pick first valid layout).

4) AutoFix framework
- Purpose: Provide a safe, reversible interface for simple code autofixes (backups created; findings recorded).
- API:
  - Invoke-SemanticConsoleAutoFix -Path <scriptsPath>
- Inputs: path to scan; rules expressed as small modifiers.
- Outputs: modifies files in-place with backups, records Add-Finding entries (via health_check context).
- Error modes: write failures, regex replace mistakes.
- Edge cases: binary files (skip), encoding preservation (preserve UTF-8), multiple candidate insert points.

5) Policy helpers
- Purpose: Centralize policy checks (chat_context change policy, top-level count) that can be used in CLI and CI.
- API:
  - Test-ChatContextChangePolicy -Root <path>
  - Test-ContextTopLevelCount -Root <path> -MaxItems <int> -AutoFix
- Inputs: repo root, thresholds.
- Outputs: emits Add-Finding entries to the global results collection used by health_check.
- Error modes: not-a-git-repo, missing diff base; should return warning and not throw in CI.

Testing & CI
------------
- Provide small smoke tests under `scripts/tests/` for each lib (runlog, checksum wrapper, jdk-installer dry checks where feasible).
- Add a GitHub Actions workflow to run `scripts/tests/*` and `scripts/health_check.ps1 -Scope project -Report json` on PRs. Workflow input should allow soft vs strict enforcement.

Notes
-----
- Keep wrappers thin and backward-compatible: existing scripts that dot-source `logging.ps1` and `Verify-FileChecksum.ps1` should continue to work. New code should prefer the `*Ex` facades to gain structured logging.
- Avoid broad in-place rewrites in a single change; prefer incremental migrations and smoke tests after each step.
