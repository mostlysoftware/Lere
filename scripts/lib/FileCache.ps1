<#
.SYNOPSIS
  File content caching and pattern matching utilities.

.DESCRIPTION
  Provides cached file reading to avoid re-reading the same files multiple times
  during audit operations. Also provides unified pattern matching with optional
  tag validation.

.EXAMPLE
  $cache = New-FileCache
  $content = Get-CachedContent -Cache $cache -Path "file.md"
  $matches = Find-PatternMatches -Cache $cache -Files $files -Pattern $regex
#>

# Global file cache (content and lines)
$script:FileCache = @{}

function New-FileCache {
  <#
  .SYNOPSIS
    Create a new file cache dictionary.
  #>
  return @{}
}

function Clear-FileCache {
  <#
  .SYNOPSIS
    Clear the global file cache.
  #>
  param(
    [hashtable]$Cache = $null
  )

  if ($Cache) {
    $Cache.Clear()
  } else {
    $script:FileCache.Clear()
  }
}

function Get-CachedContent {
  <#
  .SYNOPSIS
    Get file content with caching. Returns both raw content and lines.
  .PARAMETER Cache
    The cache hashtable to use. If not provided, uses global cache.
  .PARAMETER Path
    Path to the file.
  .PARAMETER AsLines
    If true, return as array of lines. Default returns raw content.
  #>
  param(
    [hashtable]$Cache = $null,
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [switch]$AsLines
  )

  if (-not $Cache) { $Cache = $script:FileCache }

  if (-not $Cache.ContainsKey($Path)) {
    try {
      $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
      $lines = Get-Content -LiteralPath $Path -ErrorAction Stop
      $Cache[$Path] = @{
        Raw = $raw
        Lines = $lines
      }
    } catch {
      return $null
    }
  }

  if ($AsLines) {
    return $Cache[$Path].Lines
  }
  return $Cache[$Path].Raw
}

function Find-PatternMatches {
  <#
  .SYNOPSIS
    Find regex pattern matches across multiple files with caching.
  .PARAMETER Cache
    The file cache to use.
  .PARAMETER Files
    Array of file paths to search.
  .PARAMETER Pattern
    Regex pattern to match.
  .PARAMETER ValidateTag
    If true, only accept matches that are valid tag names (alphanumeric, dash, underscore).
  .PARAMETER SkipExampleLines
    If true, skip lines containing <!-- example -->. Default: true.
  .OUTPUTS
    Array of PSCustomObject with Path, Line, Match properties.
  #>
  param(
    [hashtable]$Cache = $null,
    [Parameter(Mandatory=$true)]
    [string[]]$Files,
    [Parameter(Mandatory=$true)]
    [regex]$Pattern,
    [switch]$ValidateTag,
    [bool]$SkipExampleLines = $true
  )

  if (-not $Cache) { $Cache = $script:FileCache }

  $foundMatches = @()

  foreach ($f in $Files) {
    $lines = Get-CachedContent -Cache $Cache -Path $f -AsLines
    if ($null -eq $lines) { continue }

    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]

      # Skip example lines if requested
      if ($SkipExampleLines -and $line -match '<!--\s*example\s*-->') {
        continue
      }

      foreach ($m in ($Pattern.Matches($line))) {
        $val = $m.Groups[1].Value

        # Optional tag validation
        if ($ValidateTag -and $val -notmatch '^[A-Za-z0-9_\-]+$') {
          continue
        }

        $foundMatches += [PSCustomObject]@{
          Path  = $f
          Line  = $i + 1
          Match = $val
          FullMatch = $m.Value
        }
      }
    }
  }

  return $foundMatches
}

function Find-RawPatternMatches {
  <#
  .SYNOPSIS
    Find regex pattern matches in raw file content (for multi-line patterns).
  .PARAMETER Cache
    The file cache to use.
  .PARAMETER Path
    Path to the file.
  .PARAMETER Pattern
    Regex pattern to match.
  .OUTPUTS
    Array of regex match objects.
  #>
  param(
    [hashtable]$Cache = $null,
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [regex]$Pattern
  )

  if (-not $Cache) { $Cache = $script:FileCache }

  $content = Get-CachedContent -Cache $Cache -Path $Path
  if ($null -eq $content) { return @() }

  return $Pattern.Matches($content)
}

# Only export when loaded as a module (not dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
  Export-ModuleMember -Function New-FileCache, Clear-FileCache, Get-CachedContent, Find-PatternMatches, Find-RawPatternMatches
}
