<#
.SYNOPSIS
  Shared functions for detecting duplicated blocks of text across files.

.DESCRIPTION
  Provides Get-DuplicateBlocks and Write-DuplicateReport which other scripts
  can call programmatically. Supports excludes and configurable min-lines.
#>

function Get-DuplicateBlocks {
  param(
    [Parameter(Mandatory=$true)][string]$RootPath,
    [string[]]$IncludePaths = @('chat_context'),
    [int]$MinLines = 5,
    [string[]]$Extensions = @('.md', '.ps1', '.txt'),
    [string[]]$ExcludePaths = @()
  )

  function Compute-Hash([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = New-Object -TypeName System.Security.Cryptography.SHA1Managed
    $hashBytes = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hashBytes)).Replace('-','').ToLower()
  }

  $allFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
  foreach ($p in $IncludePaths) {
    $full = Join-Path -Path $RootPath -ChildPath $p
    if (-not (Test-Path $full)) { continue }
    $items = Get-ChildItem -Path $full -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $Extensions -contains $_.Extension }
    foreach ($it in $items) { $allFiles.Add($it) }
  }

  # Apply excludes (by path prefix)
  if ($ExcludePaths -and $ExcludePaths.Count -gt 0) {
    $filtered = @()
    foreach ($f in $allFiles) {
      $skip = $false
      foreach ($ex in $ExcludePaths) {
        $exFull = Join-Path -Path $RootPath -ChildPath $ex
        if ($f.FullName -like "$exFull*") { $skip = $true; break }
      }
      if (-not $skip) { $filtered += $f }
    }
    $allFiles = $filtered
  }

  $blocks = @{}

  foreach ($f in $allFiles) {
  try { $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction Stop) } catch { continue }
    for ($i = 0; $i -lt $lines.Count; $i++) { 
      # Coerce to string to avoid unexpected types (e.g., System.Char) from Get-Content
      $lines[$i] = [string]$lines[$i]
      $lines[$i] = $lines[$i].TrimEnd()
    }
    if ($lines.Count -lt $MinLines) { continue }

    for ($i = 0; $i -le $lines.Count - $MinLines; $i++) {
      $slice = $lines[$i..($i + $MinLines - 1)] -join "`n"
      if ($slice -match '^[\s`r`n]*$') { continue }
      $h = Compute-Hash $slice
      if (-not $blocks.ContainsKey($h)) { $blocks[$h] = [System.Collections.ArrayList]::new() }
      $blocks[$h].Add([pscustomobject]@{ File = $f.FullName; Line = $i + 1; Snippet = $slice }) | Out-Null
    }
  }

  $dups = @()
  foreach ($k in $blocks.Keys) {
    $list = $blocks[$k]
    if ($list.Count -gt 1) {
      $dups += [pscustomobject]@{ Hash = $k; Count = $list.Count; Instances = $list; Sample = $list[0].Snippet }
    }
  }

  return $dups
}

function Write-DuplicateReport {
  param(
    [Parameter(Mandatory=$true)][object]$Duplicates,
    [Parameter(Mandatory=$true)][string]$OutDir,
    [string]$Prefix = 'duplicates'
  )

  if (-not (Test-Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory -Force | Out-Null }
  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $outJson = Join-Path -Path $OutDir -ChildPath "$Prefix-$timestamp.json"
  [System.IO.File]::WriteAllText($outJson, (ConvertTo-Json $Duplicates -Depth 5 -Compress))
  return $outJson
}
