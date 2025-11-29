<# Simple smoke test for Verify-FileChecksumEx #>
. "$PSScriptRoot\..\lib\checksum.ps1"

$tmp = Join-Path $env:TEMP "test_checksum_$(Get-Random).txt"
Set-Content -Path $tmp -Value 'test' -Encoding UTF8

# compute expected using existing helper if available
try { . "$PSScriptRoot\..\lib\Verify-FileChecksum.ps1" } catch { }
try {
  $computed = Get-FileSha256 -FilePath $tmp
} catch {
  $computed = ''
}

try {
  $res = Verify-FileChecksumEx -FilePath $tmp -ExpectedChecksum $computed
  if ($res.Verified) { Write-Host 'OK: checksum ex verified' ; exit 0 } else { Write-Host "FAIL: checksum mismatch: $($res.Message)" ; exit 2 }
} catch {
  Write-Host "FAIL: Verify-FileChecksumEx threw -> $($_.Exception.Message)"; exit 2
} finally {
  Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
}
