<# Simple test for Verify-FileChecksum helper #>
. "$PSScriptRoot\..\lib\Verify-FileChecksum.ps1"

$tmp = Join-Path $env:TEMP "verify-checksum-test-$(Get-Random).txt"
"hello-checksum-test" | Out-File -FilePath $tmp -Encoding UTF8 -Force

$computed = Get-FileSha256 -FilePath $tmp
Write-Host "Computed SHA256: $computed"

$res = Verify-FileChecksum -FilePath $tmp -ExpectedChecksum $computed
Write-Host "Verified: $($res.Verified) ; Message: $($res.Message)"

if (-not $res.Verified) { Write-Error "Checksum helper test failed" ; exit 1 } else { Write-Host "Checksum helper test passed" ; exit 0 }
