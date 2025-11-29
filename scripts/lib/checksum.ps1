<#
.SYNOPSIS
  Thin wrapper around Verify-FileChecksum helper that provides a stable wrapper
  API for other scripts to call and optionally emit structured logs.
#>

try { . "$PSScriptRoot\Verify-FileChecksum.ps1" } catch { }
try { . "$PSScriptRoot\runlog.ps1" } catch { }

function Verify-FileChecksumEx {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string]$ExpectedChecksum,
        [string]$ManifestUrl
    )
    # Call existing helper and return the object; also emit a structured log entry
    try {
        $res = Verify-FileChecksum -FilePath $FilePath -ExpectedChecksum $ExpectedChecksum -ManifestUrl $ManifestUrl
    } catch {
        $res = [pscustomobject]@{ Verified = $false; Expected = $ExpectedChecksum; Computed = $null; Algorithm = 'sha256'; Message = "Exception: $($_.Exception.Message)" }
    }

    try {
        $meta = @{ file = $FilePath; verified = $res.Verified; expected = $res.Expected; computed = $res.Computed }
        if (Get-Command -Name Write-StructuredLog -ErrorAction SilentlyContinue) {
            $lvl = (if ($res.Verified) { 'Info' } else { 'Warn' })
            $msg = ("Checksum result for " + $FilePath + ": " + [string]$res.Message)
            Write-StructuredLog -Level $lvl -Message $msg -Metadata $meta
        }
    } catch { }

    return $res
}

# end checksum.ps1
