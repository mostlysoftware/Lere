function Get-FileSha256 {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath
    )
    if (-not (Test-Path $FilePath)) { throw "File not found: $FilePath" }
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($FilePath)
        $hash = $sha256.ComputeHash($stream)
        $stream.Close()
        $hex = ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
        return $hex
    } catch {
        throw "Failed to compute SHA256: $($_.Exception.Message)"
    }
}

function Verify-FileChecksum {
    <#
    .SYNOPSIS
      Verify SHA256 checksum of a local file.

    .PARAMETER FilePath
      Path to the file to verify.

    .PARAMETER ExpectedChecksum
      Optional expected hex-encoded checksum string to compare against.

    .PARAMETER ManifestUrl
      Optional URL pointing to a JSON manifest that contains checksum(s). This helper
      will try to parse the JSON and locate a plausible checksum field.

    .OUTPUTS PSCustomObject
      Returns object: @{ Verified = bool; Expected = string; Computed = string; Algorithm = 'sha256'; Message = string }
    #>
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string]$ExpectedChecksum,
        [string]$ManifestUrl
    )

    $result = [ordered]@{ Verified = $false; Expected = $null; Computed = $null; Algorithm = 'sha256'; Message = $null }
    try {
        $computed = Get-FileSha256 -FilePath $FilePath
        $result.Computed = $computed
    } catch {
        $result.Message = "Failed to compute checksum: $($_.Exception.Message)"
        return ([pscustomobject]$result)
    }

    if ($PSBoundParameters.ContainsKey('ExpectedChecksum') -and $ExpectedChecksum) {
        $result.Expected = $ExpectedChecksum.ToLower()
        if ($result.Computed -eq $result.Expected) { $result.Verified = $true; $result.Message = 'OK' } else { $result.Message = 'Mismatch' }
        return ([pscustomobject]$result)
    }

    if ($PSBoundParameters.ContainsKey('ManifestUrl') -and $ManifestUrl) {
        try {
            $txt = Invoke-RestMethod -Uri $ManifestUrl -UseBasicParsing -ErrorAction Stop
            # Attempt to find first plausible checksum string in the JSON object
            function Find-ChecksumInObject([object]$obj) {
                if ($null -eq $obj) { return $null }
                if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
                    foreach ($child in $obj) { $c = Find-ChecksumInObject $child; if ($c) { return $c } }
                } else {
                    # If object has properties, inspect them
                    try {
                        $props = $obj | Get-Member -MemberType NoteProperty,Property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -ErrorAction SilentlyContinue
                    } catch { $props = @() }
                    foreach ($p in $props) {
                        try {
                            $val = $obj.$p
                            if ($val -is [string] -and $val.Length -ge 64) {
                                # basic hex test
                                if ($val -match '^[0-9a-fA-F]{64,}$') { return $val }
                            }
                            $rec = Find-ChecksumInObject $val
                            if ($rec) { return $rec }
                        } catch { }
                    }
                }
                return $null
            }
            $found = Find-ChecksumInObject $txt
            if ($found) {
                $result.Expected = $found.ToLower()
                if ($result.Computed -eq $result.Expected) { $result.Verified = $true; $result.Message = 'OK' } else { $result.Message = 'Mismatch' }
                return ([pscustomobject]$result)
            } else {
                $result.Message = 'No checksum found in manifest'
                return ([pscustomobject]$result)
            }
        } catch {
            $result.Message = "Failed to fetch/parse manifest: $($_.Exception.Message)"
            return ([pscustomobject]$result)
        }
    }

    $result.Message = 'No expected checksum or manifest URL provided'
    return ([pscustomobject]$result)
}

# Note: this file is intended to be dot-sourced by scripts. Avoid calling Export-ModuleMember
# here because that emits a warning when the file is dot-sourced instead of imported as a module.
