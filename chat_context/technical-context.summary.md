<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\technical-context.md -->
<!-- lines: 170 -->

(Memory File)

# Technical Context

**Purpose:** Environment setup, hosting strategies, migration notes, and performance benchmarks. Keeps infrastructure separate from design.

---

## Hosting Strategy

- Likely digital ocean for affordability, with possibility of transition to AWS or similar if needs evolve.

### Minimum Viable Hosting Setup

This is the resolved answer to the open question about the minimum viable hosting setup for testing Phase 1.

- **Baseline hardware**: 2 vCPUs, 4â€“8 GB RAM (start at 4 GB; upgrade if Paper server consistently hits >3 GB heap), 60 GB SSD, and 1 Gbps net. Use a low-cost provider (DigitalOcean Basic/General Purpose, Hetzner CX31, or Azure B1ms) so the team can spin spin up/down quickly.
- **Operating system**: Ubuntu 24.04 LTS (or Windows Server 2022 if Windows-specific tooling is required). Keep the host minimal (no GUI) and apply unattended upgrades from day 1.
- **Runtime stack**:
  1. Install Java 21 LTS (Temurin or Microsoft build) via package manager or SDKMAN; pin the version in `technical-context` resource inventory once chosen.
  2. Download the latest Paper 1.20.4+ jar and place it under `/srv/lere/server.jar` (or similar). Adopt the vanilla `eula.txt`-driven first run to generate baseline configs.
  3. Configure a `systemd` service (or scheduled PowerShell task) that launches the server with `-Xms1G -Xmx3G` and auto-restarts on failure, logging to `/var/log/lere-server.log`.
  4. Mount a dedicated data disk for world and plugin files; snapshot regularly (daily) and prune old snapshots in `scripts/snapshot-prune.ps1`.
- **Networking/security**: Open only the Minecraft port (25565) and SSH (22/whatever) through firewall; add fail2ban or similar. Use a static IP or DNS entry documented in `changelog-context`.
- **Local testing alternative**: Mirror the above by running the same Paper jar on a local dev box (Linux/WSL) with 6 GB RAM and supporting `./gradlew runServer`. This ensures parity before pushing changes to the hosted environment.



## Migration Notes

- Expand later with notes on containerization and portability



## Performance Benchmarks:

- Expand later when needed, for logging benchmarks like tps, ram usage, player cap

## Resource Context


*...preview truncated; full content available on demand.*

