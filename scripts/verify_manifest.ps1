param(
  [string]$ManifestPath
)

if (-not $ManifestPath) { Write-Host "Usage: verify_manifest.ps1 -ManifestPath <path>"; exit 2 }
if (-not (Test-Path $ManifestPath)) { Write-Host "Manifest not found: $ManifestPath"; exit 3 }

try {
  $manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
} catch {
  Write-Host "Failed to read manifest: $($_.Exception.Message)"; exit 4
}

$errors = @()
foreach ($entry in $manifest.files) {
  $full = $entry.fullPath
  if (-not (Test-Path $full)) {
    $errors += "Missing file: $full"
    continue
  }
  try {
    $h = (Get-FileHash -Algorithm SHA256 -Path $full).Hash
    if ($h -ne $entry.sha256) { $errors += "Hash mismatch: $full (expected $($entry.sha256), got $h)" }
  } catch {
    $errors += "Failed to hash $full: $($_.Exception.Message)"
  }
}

if ($errors.Count -gt 0) {
  Write-Host "Manifest verification failed with the following issues:" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host " - $_" }
  exit 1
} else {
  Write-Host "Manifest verified OK: $ManifestPath" -ForegroundColor Green
  exit 0
}
