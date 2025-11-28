<#
.SYNOPSIS
  Generates a manifest of files with hashes, encoding info, and metadata.

.DESCRIPTION
  Scans a directory and produces a JSON manifest containing:
  - SHA256 hashes
  - File sizes
  - BOM detection (UTF8-BOM, UTF16-LE, UTF16-BE, None)
  - Newline format (LF, CRLF)
  - Last write time

.PARAMETER TargetDir
  The directory to scan.

.PARAMETER OutFile
  Path for the output manifest JSON file.

.PARAMETER ExcludePatterns
  Array of regex patterns to exclude from scanning.

.EXAMPLE
  $manifest = New-Manifest -TargetDir "C:\project\chat_context" -OutFile "manifest.json"
#>

function New-Manifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$TargetDir,

    [Parameter(Mandatory=$true)]
    [string]$OutFile,

    [string]$RootPath = $null,

    [string[]]$ExcludePatterns = @('\.git\\')
  )

  if (-not $RootPath) {
    $RootPath = $TargetDir
  }

  if (-not (Test-Path $TargetDir)) {
    throw "Target directory not found: $TargetDir"
  }

  # Ensure output directory exists
  $outDir = Split-Path $OutFile -Parent
  if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }

  $manifestObj = [PSCustomObject]@{
    generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    root = $RootPath
    files = @()
  }

  $files = Get-ChildItem -LiteralPath $TargetDir -Recurse -File -ErrorAction SilentlyContinue

  # Apply exclusion filters
  foreach ($pattern in $ExcludePatterns) {
    $files = $files | Where-Object { $_.FullName -notmatch $pattern }
  }

  foreach ($f in $files) {
    try {
      $full = $f.FullName

      # Compute relative path
      if ($full.Length -gt $RootPath.Length -and $full.StartsWith($RootPath)) {
        $rel = $full.Substring($RootPath.Length).TrimStart('\')
      } else {
        $rel = [System.IO.Path]::GetFileName($full)
      }

      # Get SHA256 hash
      $hashObj = Get-FileHash -Algorithm SHA256 -Path $full -ErrorAction Stop

      # Detect BOM
      $bom = Get-FileBOM -Path $full

      # Detect newline format
      $newline = Get-FileNewlineFormat -Path $full

      $entry = [PSCustomObject]@{
        path      = $rel -replace '\\','/'
        fullPath  = $full
        size      = $f.Length
        sha256    = $hashObj.Hash
        bom       = $bom
        newline   = $newline
        lastWrite = $f.LastWriteTimeUtc.ToString('o')
      }

      $manifestObj.files += $entry
    } catch {
      Write-Warning "Failed to inspect $($f.FullName): $($_.Exception.Message)"
    }
  }

  # Write manifest using atomic write if available
  $libPath = Join-Path $PSScriptRoot 'Write-Atomically.ps1'
  if (Test-Path $libPath) {
    . $libPath
    Write-Atomically -Path $OutFile -Content ($manifestObj | ConvertTo-Json -Depth 5)
  } else {
    $manifestObj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutFile -Encoding UTF8
  }

  return $manifestObj
}

function Get-FileBOM {
  <#
  .SYNOPSIS
    Detect the byte-order mark of a file.
  #>
  param([string]$Path)

  try {
    $fs = [System.IO.File]::OpenRead($Path)
    $bomBytes = New-Object byte[] 4
    $read = $fs.Read($bomBytes, 0, 4)
    $fs.Close()

    if ($read -ge 3 -and $bomBytes[0] -eq 0xEF -and $bomBytes[1] -eq 0xBB -and $bomBytes[2] -eq 0xBF) {
      return 'UTF8-BOM'
    } elseif ($read -ge 2 -and $bomBytes[0] -eq 0xFF -and $bomBytes[1] -eq 0xFE) {
      return 'UTF16-LE'
    } elseif ($read -ge 2 -and $bomBytes[0] -eq 0xFE -and $bomBytes[1] -eq 0xFF) {
      return 'UTF16-BE'
    }
  } catch { }

  return 'None/Unknown'
}

function Get-FileNewlineFormat {
  <#
  .SYNOPSIS
    Detect the predominant newline format in a text file.
  #>
  param([string]$Path)

  try {
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ($null -eq $content) { return 'Unknown' }

    $crlf = ([regex]::Matches($content, "`r`n")).Count
    $lf = ([regex]::Matches($content, "(?<!\r)`n")).Count

    if ($crlf -gt $lf) { return 'CRLF' }
    elseif ($lf -gt 0) { return 'LF' }
  } catch { }

  return 'Unknown'
}

# Only export when loaded as a module (not dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
  Export-ModuleMember -Function New-Manifest, Get-FileBOM, Get-FileNewlineFormat
}
