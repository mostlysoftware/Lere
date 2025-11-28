<##
# ArchiveWriter.ps1
#
# Shared helper to write archive files atomically with retries.
# Prefer the existing Write-Atomically library when present; otherwise
# fall back to a conservative, well-tested temp-file + Move-Item retry loop.
#
# Public function:
#   Write-AtomicArchive -Path <string> -Content <string> [-MaxRetries <int>] [-DelayMs <int>]
# Returns: $true on success, $false on failure.
##>

function Write-AtomicArchive {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)] [string]$Path,
    [Parameter(Mandatory=$true)] [string]$Content,
    [int]$MaxRetries = 5,
    [int]$DelayMs = 250,
    [ValidateSet('UTF8','Unicode','Ascii','Default')]
    [string]$Encoding = 'UTF8'
  )

  # Try to use the project's Write-Atomically if available (backwards compatibility)
  try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  } catch {
    $scriptDir = Split-Path -Parent $PSCommandPath
  }

  $writeAtomicallyPath = Join-Path $scriptDir 'Write-Atomically.ps1'
  if (Test-Path $writeAtomicallyPath) {
    try {
      . $writeAtomicallyPath
      if (Get-Command -Name Write-Atomically -ErrorAction SilentlyContinue) {
        return [bool](Write-Atomically -Path $Path -Content $Content -Encoding $Encoding)
      }
    } catch {
      # If the library exists but errors, fall through to the safe inline fallback
    }
  }

  # Inline fallback: write to temp file and move into place with retries
  $success = $false
  $tempFile = "$Path.tmp"

  for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    try {
      switch ($Encoding) {
        'UTF8'    { Set-Content -LiteralPath $tempFile -Value $Content -Encoding UTF8 }
        'Unicode' { Set-Content -LiteralPath $tempFile -Value $Content -Encoding Unicode }
        'Ascii'   { Set-Content -LiteralPath $tempFile -Value $Content -Encoding Ascii }
        default   { Set-Content -LiteralPath $tempFile -Value $Content -Encoding UTF8 }
      }
      Move-Item -Path $tempFile -Destination $Path -Force
      $success = $true
      break
    } catch {
      if (Test-Path $tempFile) { Remove-Item -LiteralPath $tempFile -ErrorAction SilentlyContinue }
      Start-Sleep -Milliseconds $DelayMs
    }
  }

  return $success
}

Export-ModuleMember -Function Write-AtomicArchive
