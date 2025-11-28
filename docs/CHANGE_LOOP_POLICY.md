# Change Loop Detection & Preferred Outcome Policy

When edits keep getting made, undone, and remade, that signals conflicting directives (e.g., automation vs. manual preference, local fix vs. CI rollback). This document explains how to spot those loops and what outcome we officially prefer so the conflict is resolved once and for all.

## Step 1: Run the loop detector

Use the helper at `scripts/lib/detect_change_loop.ps1`. It inspects the most recent commits and flags any file touched in at least `--Threshold` commits (default: 2). A typical invocation:

```powershell
.
\scripts\lib\detect_change_loop.ps1 -LookbackCommits 30 -Threshold 2
```

If the script reports files, examine the listed commits to understand who is writing and who is reverting. The first goal is to identify the conflicting agent (script vs. person, workflow vs. local change) and capture that tension in this policy.

## Step 2: Document the preferred outcome

Once a loop is confirmed, we break the cycle by codifying the intended steady state. The policy below lists the conflicting directives we already know about and declares the ``preferred outcome`` so everyone agrees which direction the change should flow. Add new rows whenever a fresh conflict arises.

| Conflicting directives | Preferred outcome | Notes |
|------------------------|------------------|-------|
| Local edits vs. auto-apply CI for pruning | Keep the CI automation as the source of truth for high-impact/low-risk prunes, while documenting manual overrides in `docs/PRUNING_POLICY.md` and the manifest. If a local change is needed, update the automation config (e.g., `ProjectConfig.Prune.AutoApproveHighImpactLowRisk`) rather than repeatedly reverting the CI commit. | We rely on the CI job to maintain trimmed audit files and avoid manual reverts. When disagreements occur, update `ProjectConfig` and re-run `tools/run_prune.ps1` in dry-run mode first. |
| Health-check warnings and `SCRIPTS.md` generator mismatches | Treat the generator output as authoritative. If a human edit keeps being reverted by the generator, examine the inline comments or the source script documentation and fix them there, not in `SCRIPTS.md`. Keep `scripts/generate_scripts_summary.ps1` in sync with the code so the generator remains a reliable source. | Keep a reasoning thread (e.g., `[#scripts-summary-loop]`) if repeated mismatches cover a broader enforcement question. |
| Snapshot naming conventions | Prefer explicit timestamped directories (e.g., `snapshot-20251128-...`) and update any automation to match them; do not oscillate by manually renaming archives. Document the naming policy in `docs/SNAPSHOT_README.md`. | This prevents health checks from flagging missing snapshots after CI pushes one standard name. |

## Step 3: Update automation or documentation

After resolving the preferred outcome, update the relevant automation script, policy, or config so the loop cannot recur. That may include:

- Adjusting the auto-apply workflow or `ProjectConfig` so it no longer conflicts with a developer action.
- Adding pointer tags or reasoning thread links to justify why one outcome is chosen.
- Logging the final decision in `changelog-context.md` referencing this policy file.

## Continuous monitoring

`health_check.ps1` now runs the change-loop detector automatically when you invoke it with the `all` or `project` scope, so any repeated edits will surface as an `automation` warning (with the commits/files listed). Run `.\scripts\health_check.ps1 -Scope all` regularly and treat that warning as the signal to resolve the conflicting directives described in this policy. If you still need a dedicated scan, run `scripts/lib/detect_change_loop.ps1` manually with a larger `-LookbackCommits`/`-Threshold`.

If health-check outputs a warning, tag the next reasoning thread with `[changelog-entry:YYYY-MM-DD HH:MM]` linking back to this policy so the loop's resolution is traceable.

### Tuning the detector

Set `ProjectConfig.Health.ChangeLoop.ExcludePaths` to a list of relative paths or glob patterns (forward slashes are supported) if certain files should never trigger the detector. By default the health check already ignores `chat_context/.obsidian/workspace.json` because IDE state files tend to flip every commit. Add other entries (for example `chat_context/archives/*.md` or `docs/generated/*`) so you can keep the automation on without noise. Changes to this setting are picked up the next time `health_check.ps1` runs, and the warning will list the configured exclude list for auditing.
