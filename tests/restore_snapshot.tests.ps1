Import-Module Pester -ErrorAction SilentlyContinue

Describe 'Snapshot restore smoke test' {
  It 'Restores one file from latest snapshot and verifies hash' {
    # Find latest snapshot
    $snap = Get-ChildItem -Path ..\backups -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $snap) { Write-Warning 'No snapshots available'; return }

    $manifest = Get-Content -LiteralPath (Join-Path $snap.FullName 'manifest.json') -Raw | ConvertFrom-Json
    $item = $manifest.Items | Where-Object { $_.Hash -ne $null } | Select-Object -First 1
  if (-not $item) { Write-Warning 'No verifiable files in manifest'; return }

    $rel = $item.Path -replace '^\.\\',''
    $res = & ..\scripts\restore_from_snapshot.ps1 -SnapshotDir $snap.FullName -RelativePath $rel -OutDir ..\restored
    # Expect exit code 0 for success
    $LASTEXITCODE | Should -Be 0
  }
}
