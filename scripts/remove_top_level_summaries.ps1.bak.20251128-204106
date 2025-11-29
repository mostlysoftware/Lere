param(
    [string]$ContextDir = "chat_context"
)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path .
$ctx = Resolve-Path $ContextDir
Write-Host "Context: $ctx"
$files = Get-ChildItem -Path $ctx -Filter '*.summary.md' -File | Where-Object { $_.DirectoryName -eq $ctx.Path }
if (-not $files -or $files.Count -eq 0) {
    Write-Host 'No top-level summary files found.'
    exit 0
}
foreach ($f in $files) {
    Write-Host ("DEL: " + $f.FullName)
    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
}
Write-Host 'Stage deletions'
git add -A | Out-Null
$pending = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($pending)) {
    git commit -m "chore(context): remove stray top-level .summary.md files (enforced)" | Out-Null
    git push origin HEAD | Out-Null
    Write-Host 'Committed and pushed removals.'
} else {
    Write-Host 'No changes to commit.'
}
