# Audit script: finds reasoning-thread hashes, changelog anchors, and session markers
# Performs an orphan check and exits with non-zero if missing targets are found.
#
# === FLOW ===
# 1. Load shared libraries (FileCache, Write-Atomically, New-Manifest, Parse-EntryMetadata)
# 2. Generate manifest of all files in chat_context/
# 3. Optionally normalize encodings/line endings (-Normalize)
# 4. Scan for pointer patterns: [#thread], [changelog-entry:...], (Session ...)
# 5. Build definition/reference maps for each pointer type
# 6. Report orphans (references without definitions) and broken links
# 7. Exit 0 if clean, exit 1 if broken pointers found
#
# === POINTER TYPES ===
# - Reasoning: [#thread-name] references, ## Reasoning Thread: [name] definitions
# - Changelog: [changelog-entry:YYYY-MM-DD HH:MM] as both ref and anchor
# - Session: (Session YYYY-MM-DD HH:MM) markers
#
# === OPTIONS ===
# -AutoFix    : Reserved for future auto-correction
# -Normalize  : Convert all files to UTF-8 no BOM, LF line endings
# -CheckBuild : Run build environment checks (Java, Gradle)
# -CheckBloat : Warn about oversized files

param(
  [switch]$AutoFix = $false,
  [switch]$Normalize = $false,
  [switch]$CheckBuild = $false,
  [switch]$CheckBloat = $false,
  [int]$MaxLines = 500,
  [int]$MaxSizeKB = 50
)

# === Load shared libraries ===
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'FileCache.ps1')
. (Join-Path $libDir 'Write-Atomically.ps1')
. (Join-Path $libDir 'New-Manifest.ps1')
. (Join-Path $libDir 'Parse-EntryMetadata.ps1')

# === Configuration ===
$root = (Resolve-Path -Path "$PSScriptRoot\..").Path
$targetDir = Join-Path $root 'chat_context'
$manifestOutDir = Join-Path $root 'scripts\audit-data\manifests'
$archivesDir = Join-Path $root 'chat_context\archives'

# Sensitive pattern definitions (for privacy scans)
$script:SensitivePatterns = @{
  'Email' = [regex]'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})'
  'WindowsUserPath' = [regex]'C:\\Users\\[A-Za-z0-9._-]+'
}
$script:AllowedEmails = @('git@github.com', 'noreply@github.com')
$script:AllowedPaths = @('C:\Users\user', 'C:\Users\<USER_HOME>')

Write-Host "Running chat_context audit in $root (AutoFix=$AutoFix)" -ForegroundColor Cyan

# === Initialize file cache ===
$cache = New-FileCache

# === Generate manifest ===
Write-Host "Generating local manifest..." -ForegroundColor Cyan
if (-not (Test-Path $manifestOutDir)) {
  New-Item -ItemType Directory -Path $manifestOutDir -Force | Out-Null
}
$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$manifestFile = Join-Path $manifestOutDir "manifest-$ts.json"

if (Test-Path $targetDir) {
  try {
    $manifest = New-Manifest -TargetDir $targetDir -OutFile $manifestFile -RootPath $root
    Write-Host "Manifest generated: $manifestFile ($($manifest.files.Count) files)" -ForegroundColor Green
  } catch {
    Write-Host "Warning: manifest generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
  }

  # === Normalize mode ===
  if ($Normalize) {
    Write-Host "Normalize enabled: normalizing encodings and line endings..." -ForegroundColor Cyan
    $textFiles = Get-ChildItem -LiteralPath $targetDir -Recurse -File -Include *.md,*.txt,*.json,*.yml,*.yaml -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch '\\archives\\' -and $_.FullName -notmatch '\\.obsidian\\' -and $_.Name -notmatch '^manifest-' }

    $enc = [System.Text.UTF8Encoding]::new($false)
    foreach ($tf in $textFiles) {
      try {
        $orig = Get-Content -LiteralPath $tf.FullName -Raw -ErrorAction Stop
        if ($null -eq $orig) { continue }

        # Normalize newlines to LF
        $normalized = $orig -replace "`r`n", "`n" -replace "`r", "`n"

        Write-Atomically -Path $tf.FullName -Content $normalized -Encoding $enc
        Write-Host "Normalized: $($tf.FullName)" -ForegroundColor Green
      } catch {
        Write-Host "Warning: failed to normalize $($tf.FullName): $($_.Exception.Message)" -ForegroundColor Yellow
      }
    }

    # Regenerate manifest after normalization
    Clear-FileCache -Cache $cache
    $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $manifestFile = Join-Path $manifestOutDir "manifest-$ts.json"
    $manifest = New-Manifest -TargetDir $targetDir -OutFile $manifestFile -RootPath $root
    Write-Host "Post-normalize manifest generated: $manifestFile" -ForegroundColor Green
  }
} else {
  Write-Host "Manifest skipped: chat_context not found at $targetDir" -ForegroundColor Yellow
}

# === Gather markdown files ===
$mdFiles = Get-ChildItem -Path $targetDir -Recurse -Include *.md -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName

# === Pointer Audits ===

# 1) Reasoning thread references [#name]
$refPattern = [regex]'\[#([^\]]+)\]'
$rawRefsObjs = Find-PatternMatches -Cache $cache -Files $mdFiles -Pattern $refPattern -ValidateTag
$refs = $rawRefsObjs | Select-Object -ExpandProperty Match -Unique

Write-Host "`nRaw reasoning refs found (file:line:tag):" -ForegroundColor Cyan
$rawRefsObjs | ForEach-Object { Write-Host " - $($_.Path):$($_.Line): $($_.Match)" }

# Collect definitions from reasoning-context.md and archives
$reasoningFile = Join-Path $root 'chat_context\reasoning-context.md'
$defPattern = [regex]'##\s+Reasoning Thread:\s*\[([^\]]+)\]'
$defs = @()

if (Test-Path $reasoningFile) {
  $content = Get-CachedContent -Cache $cache -Path $reasoningFile
  foreach ($m in ($defPattern.Matches($content))) { $defs += $m.Groups[1].Value }
}

# Also scan reasoning archive files
$reasoningArchives = Get-ChildItem -Path $archivesDir -Filter 'reasoning-archive-*.md' -ErrorAction SilentlyContinue
foreach ($ra in $reasoningArchives) {
  $content = Get-CachedContent -Cache $cache -Path $ra.FullName
  if ($content) {
    foreach ($m in ($defPattern.Matches($content))) { $defs += $m.Groups[1].Value }
  }
}
$defs = $defs | Sort-Object -Unique

$missingReasoning = $refs | Where-Object { $_ -and $defs -notcontains $_ }

# 2) Changelog anchors
$changelogRefPattern = [regex]'\[changelog-entry:(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]'
$changelogRefs = Find-PatternMatches -Cache $cache -Files $mdFiles -Pattern $changelogRefPattern |
  Select-Object -ExpandProperty Match -Unique

$changelogFile = Join-Path $root 'chat_context\changelog-context.md'
$changelogDefs = @()
if (Test-Path $changelogFile) {
  $content = Get-CachedContent -Cache $cache -Path $changelogFile
  foreach ($m in ($changelogRefPattern.Matches($content))) { $changelogDefs += $m.Groups[1].Value }
  $changelogDefs = $changelogDefs | Sort-Object -Unique
}

$missingChangelog = $changelogRefs | Where-Object { $_ -and $changelogDefs -notcontains $_ }

# 3) Session markers
$sessionRefPattern = [regex]'\(Session (\d{4}-\d{2}-\d{2} \d{2}:\d{2})\)'
$sessionRefs = Find-PatternMatches -Cache $cache -Files $mdFiles -Pattern $sessionRefPattern |
  Select-Object -ExpandProperty Match -Unique

$sessionDefs = @()
foreach ($f in $mdFiles) {
  $content = Get-CachedContent -Cache $cache -Path $f
  if ($content) {
    foreach ($m in ($sessionRefPattern.Matches($content))) { $sessionDefs += $m.Groups[1].Value }
  }
}
$sessionDefs = $sessionDefs | Sort-Object -Unique

$missingSessions = $sessionRefs | Where-Object { $_ -and $sessionDefs -notcontains $_ }

# 4) Link existence check
$linkPattern = [regex]'\[[^\]]*\]\(([^)]+)\)'
$plainArchivePattern = [regex]'archives/[A-Za-z0-9_\-\.\*]+'
$missingLinks = @()

foreach ($f in $mdFiles) {
  $txt = Get-CachedContent -Cache $cache -Path $f
  if ($null -eq $txt) { continue }

  # Check markdown links
  foreach ($m in ($linkPattern.Matches($txt))) {
    $target = $m.Groups[1].Value
    if ($target -match '^(https?:)?//') { continue }

    $targetPath = $target -replace '/', '\'
    $resolved = Join-Path $root $targetPath

    if ($resolved -like '*[*?]*') {
      $dir = Split-Path $resolved -Parent
      $pat = Split-Path $resolved -Leaf
      if (-not (Test-Path $dir)) {
        $missingLinks += "Missing directory for link in $($f): $target"
        continue
      }
      $found = Get-ChildItem -Path $dir -Filter $pat -ErrorAction SilentlyContinue
      if (-not $found) { $missingLinks += "No match for link in $($f): $target" }
    } else {
      if (-not (Test-Path $resolved)) {
        $leaf = Split-Path $resolved -Leaf
        if ($leaf -match '^session-archive') {
          $dir = Split-Path $resolved -Parent
          $found = Get-ChildItem -Path $dir -Filter 'session-archive*.md' -ErrorAction SilentlyContinue
          if ($found) { continue }
        }
        $missingLinks += "Broken link in $($f): $target"
      }
    }
  }

  # Check plain archive pointers
  foreach ($m in ($plainArchivePattern.Matches($txt))) {
    $target = $m.Value

    # Skip example lines
    $matchStart = $m.Index
    $lineStart = $txt.LastIndexOf("`n", [Math]::Max(0, $matchStart - 1)) + 1
    $lineEnd = $txt.IndexOf("`n", $matchStart)
    if ($lineEnd -lt 0) { $lineEnd = $txt.Length }
    $line = $txt.Substring($lineStart, $lineEnd - $lineStart)
    if ($line -match '<!--\s*example\s*-->') { continue }

    $baseDir = Split-Path $f -Parent
    $resolved = Join-Path $baseDir ($target -replace '/', '\')

    if ($resolved -like '*[*?]*') {
      $dir = Split-Path $resolved -Parent
      $pat = Split-Path $resolved -Leaf
      $found = Get-ChildItem -Path $dir -Filter $pat -ErrorAction SilentlyContinue
      if (-not $found) { $missingLinks += "No match for archive pointer in $($f): $target" }
    } else {
      if (-not (Test-Path $resolved)) {
        $leaf = Split-Path $resolved -Leaf
        if ($leaf -match '^session-archive') {
          $dir = Split-Path $resolved -Parent
          $found = Get-ChildItem -Path $dir -Filter 'session-archive*.md' -ErrorAction SilentlyContinue
          if ($found) { continue }
        }
        $missingLinks += "Broken archive pointer in $($f): $target"
      }
    }
  }
}

# 5) Session Priority enforcement
$missingPriority = @()
$sessionBlockPattern = [regex]'(\(Session \d{4}-\d{2}-\d{2} \d{2}:\d{2}\))(?s)(.*?)(?=(\(Session \d{4}-\d{2}-\d{2} \d{2}:\d{2}\))|$)'

$sessionFiles = @()
$candidate = Join-Path $root 'chat_context\session-context.md'
if (Test-Path $candidate) { $sessionFiles += $candidate }
Get-ChildItem -Path "$archivesDir\session-archive*.md" -ErrorAction SilentlyContinue |
  ForEach-Object { $sessionFiles += $_.FullName }

foreach ($f in $sessionFiles) {
  $txt = Get-CachedContent -Cache $cache -Path $f
  if ($null -eq $txt) { continue }

  foreach ($m in ($sessionBlockPattern.Matches($txt))) {
    $ts = $m.Groups[1].Value
    $block = $m.Groups[2].Value
    if ($block -notmatch '(?i)Priority\s*:') {
      $missingPriority += [PSCustomObject]@{ File = $f; Session = $ts }
    }
  }
}

# === Output Summary ===
Write-Host "Audit summary:" -ForegroundColor Cyan
Write-Host "- Reasoning references found: $($refs.Count)" -ForegroundColor Yellow
Write-Host "- Reasoning definitions found: $($defs.Count)" -ForegroundColor Yellow
Write-Host "- Changelog anchors referenced: $($changelogRefs.Count)" -ForegroundColor Yellow
Write-Host "- Changelog anchors defined: $($changelogDefs.Count)" -ForegroundColor Yellow
Write-Host "- Session markers referenced: $($sessionRefs.Count)" -ForegroundColor Yellow
Write-Host "- Session markers defined: $($sessionDefs.Count)" -ForegroundColor Yellow

$hasProblems = $false

if ($missingReasoning.Count -gt 0) {
  Write-Host "`nMissing reasoning thread definitions:" -ForegroundColor Red
  $missingReasoning | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($missingChangelog.Count -gt 0) {
  Write-Host "`nMissing changelog anchors:" -ForegroundColor Red
  $missingChangelog | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($missingSessions.Count -gt 0) {
  Write-Host "`nMissing session markers:" -ForegroundColor Red
  $missingSessions | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($missingLinks.Count -gt 0) {
  Write-Host "`nBroken links or pointers:" -ForegroundColor Red
  $missingLinks | ForEach-Object { Write-Host " - $_" }
  $hasProblems = $true
}

if ($hasProblems) {
  Write-Host "`nAudit failed: found missing pointers." -ForegroundColor Red
  exit 1
}

Write-Host "`nAudit complete: no missing pointers found." -ForegroundColor Green

# === Session Priority AutoFix ===
if ($missingPriority.Count -gt 0) {
  if ($AutoFix) {
    Write-Host "`nAutoFix: inserting 'Priority: low' into session blocks..." -ForegroundColor Cyan
    $groups = $missingPriority | Group-Object -Property File

    foreach ($g in $groups) {
      $file = $g.Name
      $items = $g.Group
      $lines = Get-Content -LiteralPath $file

      foreach ($mi in $items) {
        $targetTs = $mi.Session -replace '^\(Session\s*', '' -replace '\)$', ''
        $needle = "(Session $targetTs)"

        for ($idx = 0; $idx -lt $lines.Count; $idx++) {
          if ($lines[$idx].IndexOf($needle) -ne -1) {
            $header = $lines[$idx]
            $prefix = if ($header -match '^\s*([-*]\s*)') { $Matches[1] } else { '' }
            $insertLine = "${prefix}Priority: low"
            $before = $lines[0..$idx]
            $after = if ($idx + 1 -lt $lines.Count) { $lines[($idx + 1)..($lines.Count - 1)] } else { @() }
            $lines = $before + $insertLine + $after
            break
          }
        }
      }

      Write-Atomically -Path $file -Content ($lines -join "`n")
      Write-Host "Patched $file" -ForegroundColor Green
    }
  } else {
    Write-Host "`nSession blocks missing 'Priority:' (use -AutoFix to insert defaults):" -ForegroundColor Yellow
    $missingPriority | ForEach-Object { Write-Host " - $($_.File): $($_.Session)" }
    exit 3
  }
}

# === Build Checks ===
if ($CheckBuild) {
  Write-Host "`nCheckBuild: running local plugin builds..." -ForegroundColor Cyan
  $cwd = Get-Location
  Set-Location -LiteralPath $root

  $wrapperPath = Join-Path $root 'gradlew.bat'
  $useWrapper = Test-Path $wrapperPath
  $hasGradle = (Get-Command gradle -ErrorAction SilentlyContinue) -ne $null

  if (-not $useWrapper -and -not $hasGradle) {
    Write-Host "No Gradle found; skipping build checks." -ForegroundColor Yellow
  } else {
    $projects = @('plugins\lere_core', 'plugins\lere_multiplayer')
    foreach ($p in $projects) {
      $pPath = Join-Path $root $p
      if (-not (Test-Path $pPath)) { continue }

      Write-Host "Building $p ..." -ForegroundColor Cyan
      $cmd = if ($useWrapper) { $wrapperPath } else { 'gradle' }
      $args = @('-p', $p, 'build', '--no-daemon')

      try {
        & $cmd @args
        $rc = $LASTEXITCODE
        if ($rc -eq 0) { Write-Host "Build succeeded: $p" -ForegroundColor Green }
        else { Write-Host "Build failed (non-blocking): $p" -ForegroundColor Yellow }
      } catch {
        Write-Host "Build error for $p : $($_.Exception.Message)" -ForegroundColor Yellow
      }
    }
  }
  Set-Location -LiteralPath $cwd
}

# === Bloat Analysis ===
if ($CheckBloat) {
  Write-Host "`nCheckBloat: analyzing file sizes..." -ForegroundColor Cyan
  $bloatWarnings = @()

  $contextFiles = Get-ChildItem -Path $targetDir -File -Recurse |
    Where-Object { $_.Extension -match '\.md|\.json|\.yml|\.yaml|\.txt' -and $_.FullName -notmatch '\\.obsidian\\' }

  foreach ($cf in $contextFiles) {
    $content = Get-CachedContent -Cache $cache -Path $cf.FullName
    $lineCount = if ($content) { ($content -split '\r?\n').Count } else { 0 }
    $sizeKB = [math]::Round($cf.Length / 1024, 2)
    $relPath = $cf.FullName.Substring($root.Length).TrimStart('\')

    $reasons = @()
    if ($lineCount -gt $MaxLines) { $reasons += "lines ($lineCount > $MaxLines)" }
    if ($sizeKB -gt $MaxSizeKB) { $reasons += "size (${sizeKB}KB > ${MaxSizeKB}KB)" }

    if ($reasons.Count -gt 0) {
      $bloatWarnings += [PSCustomObject]@{ File = $relPath; Lines = $lineCount; SizeKB = $sizeKB; Reasons = ($reasons -join ', ') }
    }
  }

  # Growth trend comparison
  $prevManifests = Get-ChildItem -Path $manifestOutDir -Filter 'manifest-*.json' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -Skip 1 -First 1
  $growthWarnings = @()

  if ($prevManifests) {
    try {
      $prev = Get-Content -LiteralPath $prevManifests.FullName -Raw | ConvertFrom-Json
      $prevMap = @{}
      foreach ($pf in $prev.files) { $prevMap[$pf.path] = $pf }

      foreach ($cf in $contextFiles) {
        $relPath = ($cf.FullName.Substring($root.Length).TrimStart('\')) -replace '\\', '/'
        if ($prevMap.ContainsKey($relPath)) {
          $prevSize = $prevMap[$relPath].size
          $currSize = $cf.Length
          if ($prevSize -gt 0) {
            $growth = [math]::Round((($currSize - $prevSize) / $prevSize) * 100, 1)
            if ($growth -ge 20) {
              $growthWarnings += [PSCustomObject]@{ File = $relPath; PrevSize = $prevSize; CurrSize = $currSize; Growth = "$growth%" }
            }
          }
        }
      }
    } catch {
      Write-Host "Warning: could not parse previous manifest" -ForegroundColor Yellow
    }
  }

  if ($bloatWarnings.Count -gt 0) {
    Write-Host "`nBloat warnings:" -ForegroundColor Yellow
    foreach ($bw in $bloatWarnings) {
      Write-Host " - $($bw.File): $($bw.Reasons)" -ForegroundColor Yellow
    }
  } else {
    Write-Host "No bloat warnings." -ForegroundColor Green
  }

  if ($growthWarnings.Count -gt 0) {
    Write-Host "`nGrowth warnings (20%+ since last manifest):" -ForegroundColor Yellow
    foreach ($gw in $growthWarnings) {
      Write-Host " - $($gw.File): $($gw.Growth)" -ForegroundColor Yellow
    }
  }
}

# === Privacy Scans ===
$repoFiles = Get-ChildItem -Path $root -Recurse -File |
  Where-Object { $_.FullName -notmatch '\\.git\\' }

$sensitiveFound = @()
foreach ($file in $repoFiles) {
  if ($file.Extension -notmatch '\.md|\.yml|\.yaml|\.txt|\.json|\.xml|\.properties|\.log|\.ps1|\.java|\.gradle' -and $file.Name -ne 'LICENSE') {
    continue
  }

  $text = Get-CachedContent -Cache $cache -Path $file.FullName
  if ($null -eq $text) { continue }

  foreach ($k in $script:SensitivePatterns.Keys) {
    $pat = $script:SensitivePatterns[$k]
    foreach ($m in ($pat.Matches($text))) {
      $sensitiveFound += [PSCustomObject]@{ File = $file.FullName; Pattern = $k; Match = $m.Value }
    }
  }
}

# Filter allowed patterns
$sensitiveFound = $sensitiveFound | Where-Object {
  if ($_.Pattern -eq 'WindowsUserPath') { $script:AllowedPaths -notcontains $_.Match }
  elseif ($_.Pattern -eq 'Email') { $script:AllowedEmails -notcontains $_.Match }
  else { $true }
}

if ($sensitiveFound.Count -gt 0) {
  Write-Host "`nPotential sensitive data found:" -ForegroundColor Red
  $sensitiveFound | ForEach-Object { Write-Host " - $($_.File): [$($_.Pattern)] $($_.Match)" }
  Write-Host "`nReview and sanitize before publishing." -ForegroundColor Red
  exit 2
}

exit 0
