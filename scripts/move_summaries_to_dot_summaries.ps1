Param(
    [string]$Root = 'chat_context'
)

$summaryRoot = Join-Path $Root '.summaries'
if (-not (Test-Path $summaryRoot)) { New-Item -ItemType Directory -Path $summaryRoot | Out-Null }

$files = Get-ChildItem -Path $Root -Recurse -Include *.summary.md -File -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $rel = $f.FullName.Substring((Get-Item $Root).FullName.Length + 1)
    $dest = Join-Path $summaryRoot $rel
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    git mv -f -- "$($f.FullName)" "$dest" | Out-Null
    Write-Output "Moved: $($f.FullName) -> $dest"
}
