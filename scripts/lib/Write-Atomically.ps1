<#
.SYNOPSIS
  Atomic file write helper with retry logic.

.DESCRIPTION
  Writes content to a temp file then moves it into place atomically.
  Includes retry logic for transient file locks (e.g., Dropbox, antivirus).

.PARAMETER Path
  The target file path.

.PARAMETER Content
  The content to write (string or string array).

.PARAMETER Encoding
  Optional encoding. Default: UTF8 (no BOM).

.PARAMETER MaxRetries
  Maximum retry attempts. Default: 5.

.PARAMETER RetryDelayMs
  Base delay between retries in milliseconds. Default: 200.

.EXAMPLE
  Write-Atomically -Path "C:\data\file.md" -Content $text
#>

function Write-Atomically {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    $Content,

    [System.Text.Encoding]$Encoding = [System.Text.UTF8Encoding]::new($false),

    [int]$MaxRetries = 5,

    [int]$RetryDelayMs = 200
  )

  $tempFile = "$Path.tmp"
  $success = $false

  for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
    try {
      # Convert content to string if array
      if ($Content -is [array]) {
        $text = $Content -join "`n"
      } else {
        $text = $Content
      }

      # Write to temp file
      [System.IO.File]::WriteAllBytes($tempFile, $Encoding.GetBytes($text))

      # Atomic move into place
      Move-Item -LiteralPath $tempFile -Destination $Path -Force -ErrorAction Stop

      $success = $true
      break
    } catch {
      if (Test-Path $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
      }
      if ($attempt -lt $MaxRetries) {
        Start-Sleep -Milliseconds ($RetryDelayMs * $attempt)
      }
    }
  }

  if (-not $success) {
    throw "Failed to write file atomically after $MaxRetries attempts: $Path"
  }

  return $true
}

# Only export when loaded as a module (not dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
  Export-ModuleMember -Function Write-Atomically
}
