# ArchiveDocument.ps1
# Shared helper to build and write archive documents consistently.

function Save-ArchiveDocument {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$ArchiveDir,
    [Parameter(Mandatory=$true)][string]$FileName,
    [Parameter(Mandatory=$true)][string[]]$Sections,
    [int]$MaxRetries = 5,
    [int]$DelayMs = 250,
    [ValidateSet('UTF8','Unicode','Ascii','Default')][string]$Encoding = 'UTF8'
  )

  if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
  }

  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $archiveWriter = Join-Path $scriptDir 'ArchiveWriter.ps1'
  if (-not (Test-Path $archiveWriter)) {
    throw "ArchiveWriter helper not found at $archiveWriter"
  }

  . $archiveWriter

  $content = ($Sections -join "`n").TrimEnd() + "`n"
  $outputPath = Join-Path $ArchiveDir $FileName

  $success = Write-AtomicArchive -Path $outputPath -Content $content -MaxRetries $MaxRetries -DelayMs $DelayMs -Encoding $Encoding

  [pscustomobject]@{
    Success = $success
    Path = $outputPath
  }
}

Export-ModuleMember -Function Save-ArchiveDocument
