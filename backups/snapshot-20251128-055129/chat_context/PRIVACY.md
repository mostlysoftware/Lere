 (Memory File)

## Privacy Notes

This file documents the project's privacy considerations for stored context and audit outputs.

- Ensure audit artifacts do not leak personal data.
- Audit reports are stored in `scripts/audit-data` and rotated/archived regularly.
- Sensitive patterns (emails, user paths) are detected and reported by `scripts/audit.ps1`.
