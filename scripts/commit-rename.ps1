# Create and commit the chat_context filename normalization on a branch.
#
# Usage:
#   # Create branch, commit staged deletions/changes, and show result
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\commit-rename.ps1
#
#   # Create branch, commit, and push to origin
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\commit-rename.ps1 -Push
#
# This helper checks for git availability and performs a safe commit.

param(
  [switch]$Push,
  [string]$Branch = 'rename/chat-context-lowercase'
)

function Write-Log($msg) { Write-Host $msg }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "git is not available in this environment. Run these commands locally where git is installed:" -ForegroundColor Yellow
  Write-Host "  git checkout -b $Branch"
  Write-Host "  git add -A"
  Write-Host "  git commit -m 'chore: normalize chat_context filenames to lowercase'"
  Write-Host "  git push -u origin $Branch  # optional"
  exit 1
}

try {
  # create or switch to branch
  $exists = (git rev-parse --verify $Branch 2>$null) -ne $null
  if ($exists) { git checkout $Branch } else { git checkout -b $Branch }

  # stage all changes
  git add -A

  $status = git status --porcelain
  if (-not $status) {
    Write-Log "Nothing to commit. Working tree clean."
  } else {
    git commit -m "chore: normalize chat_context filenames to lowercase"
    Write-Log "Commit created on branch '$Branch'."
  }

  if ($Push) {
    git push -u origin $Branch
    Write-Log "Pushed branch '$Branch' to origin."
  } else {
    Write-Log "Run 'git push -u origin $Branch' to push the branch when ready."
  }
} catch {
  Write-Host "Git operation failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 2
}
