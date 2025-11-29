Developer quick start
=====================

This file documents quick, one-click developer flows for this repository. It explains the VS Code tasks and local helper scripts that automate hook installation and plugin builds on Windows.

Install Git hooks (one-click / script)
------------------------------------

- Preferred (one-time, in PowerShell):

  ```powershell
  # Run the setup wrapper which sets core.hooksPath and runs the installer
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_hooks.ps1
  ```

First-time setup
----------------

Run the repository first-time helper right after cloning/pulling. It will walk you through health checks, hook installation, optional user-local JDK install, and an initial build. After it finishes, paste the script output into the AI assistant and ask for any additional environment-specific steps.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\first_time_setup.ps1
```

- Alternative: use the VS Code Task 'Install Git Hooks' (Command Palette → Tasks: Run Task).

What the hook installer does
- Sets `git config core.hooksPath .githooks` so hooks run from `.githooks/`.
- Copies platform-friendly wrappers into `.git/hooks` for non-Git clients.
- Installs pre-commit (runs `scripts/health_check.ps1 -Scope scripts`) and pre-push (runs `scripts/dev_setup.ps1 -RunBuild`).

One-click tasks (VS Code)
-------------------------

- Install Git Hooks — runs `scripts/setup_hooks.ps1` (preferred on Windows).
- Run Local Plugin Build — runs `scripts/dev_setup.ps1 -RunBuild` to build all plugins locally.

Dealing with missing JDK (common error)
--------------------------------------

If you see `javac : The term 'javac' is not recognized` in the terminal (PowerShell), you need to install a JDK and make sure `javac` is on your PATH.

Recommended installs (Windows):

- Install with winget (Windows 10/11):
  ```powershell
  winget install -e --id EclipseAdoptium.Temurin.17.JDK
  ```
- Or install with Chocolatey:
  ```powershell
  choco install temurin17 -y
  ```

After installing a JDK, confirm it is available:

```powershell
javac -version
java -version
```

If `javac` is still not found, ensure your `JAVA_HOME` is set and `%JAVA_HOME%\bin` is on your PATH.

Local build helper
------------------

Use the helper to download Gradle locally (if no wrapper) and run builds. Requires JDK present.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_setup.ps1 -RunBuild
```

If you prefer a single-click in VS Code, use the 'Run Local Plugin Build' task from the Command Palette.

If builds fail, paste the terminal output here and I'll help fix compile errors.
