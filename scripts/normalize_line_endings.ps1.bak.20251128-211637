Param(
    [string]$Root = "./chat_context"
)

$files = Get-ChildItem -Path $Root -Recurse -Include *.md,*.summary.md -File -ErrorAction SilentlyContinue
if (!$files) { Write-Info "No files found under $Root"; exit 0 }

foreach ($f in $files) {
    $path = $f.FullName
    try {
        $text = Get-Content -Raw -Encoding UTF8 -ErrorAction Stop $path
    } catch {
        # fallback to system default encoding if UTF8 read fails
        $text = Get-Content -Raw -Encoding Default $path
    }

    # Normalize any CR, LF, or CRLF into CRLF
    $normalized = $text -replace "(\r\n|\r|\n)", "`r`n"
    if (-not $normalized.EndsWith("`r`n")) { $normalized += "`r`n" }

    Set-Content -Encoding UTF8 -Force -Value $normalized $path
    Write-Info "Normalized: $path"
}

