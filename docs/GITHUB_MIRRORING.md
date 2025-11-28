# Mirroring the project to GitHub

This document explains recommended steps to mirror this project to GitHub and maintain hygiene.

1. Create a new GitHub repository (private or public depending on preference).
2. Add this repo as the remote and push the current files:

   git init
   git add .
   git commit -m "Initial project scaffold"
   git branch -M main
   git remote add origin git@github.com:YOUR_USERNAME/REPO_NAME.git
   git push -u origin main

3. Configure branch protection for `main` and require status checks (audit + build) before merging.
4. Add repository secrets if using webhook automation for Patreon or private build steps.

Notes about Dropbox

- Prefer keeping Git as the canonical source of truth. If you continue to use Dropbox for sync, be mindful of git conflicts and DO NOT use Dropbox's overwrite features while commits are in-flight.
- Best practice: move working development into the git repo folder and disable Dropbox syncing for the repo to avoid conflicts.

CI provided

- `.github/workflows/audit.yml` — runs the PowerShell audit script on pushes/PRs.
- `.github/workflows/build-plugin.yml` — builds the plugin when changes are pushed to `plugins/lere_core`.
- `.github/workflows/package-release.yml` — packages datapack + plugin jars into a release artifact on tag push or manual dispatch.

Security & licensing

- Choose a license (this repo uses MIT by default). Adjust `LICENSE` if you prefer a different license.
- Do not store private keys or tokens in the repo; use GitHub Secrets.
