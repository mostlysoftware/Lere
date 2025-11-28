<#
.SYNOPSIS
  Comprehensive health checkup for the Lere project.

.DESCRIPTION
  Runs various health checks at project, script, or plugin scope.
  
  Checks include:
  - Code quality: duplication detection, function complexity, dead code
  - File hygiene: bloat detection, encoding consistency, line endings
  - Dependency health: unused imports, outdated patterns
  - Documentation: missing headers, stale TODOs, orphan comments
  - Memory audit: pointer integrity, archive staleness, context drift

.PARAMETER Scope
  What to check: 'all', 'project', 'scripts', 'plugins', 'context'
  Default: 'all'

.PARAMETER Report
  Output format: 'console', 'json', 'markdown'
  Default: 'console'

.PARAMETER Fix
  Attempt to auto-fix simple issues (encoding, line endings)

.EXAMPLE
  # Full health check
  .\health_check.ps1

  # Scripts only, JSON output
  .\health_check.ps1 -Scope scripts -Report json

  # Plugins with auto-fix
  .\health_check.ps1 -Scope plugins -Fix
#>

param(
  [ValidateSet('all', 'project', 'scripts', 'plugins', 'context')]
  [string]$Scope = 'all',
  
  [ValidateSet('console', 'json', 'markdown')]
  [string]$Report = 'console',
  
  [switch]$Fix = $false,
  
  [switch]$Verbose = $false
)

# === Load shared libraries ===
# FileCache: Caches file content to avoid re-reading
# Write-Atomically: Safe file writes with backup/retry
# New-Manifest: Generates project manifests with file metadata
$libDir = Join-Path $PSScriptRoot 'lib'
if (Test-Path (Join-Path $libDir 'FileCache.ps1')) {
  . (Join-Path $libDir 'FileCache.ps1')
  . (Join-Path $libDir 'Write-Atomically.ps1')
  . (Join-Path $libDir 'New-Manifest.ps1')
}

# Optional: Reasoning critique library (conservative, rule-based)
$reasoningCritiquePath = Join-Path $libDir 'ReasoningCritique.ps1'
if (Test-Path $reasoningCritiquePath) { . $reasoningCritiquePath }

# === Configuration ===
# Paths are relative to script location (scripts/ folder)
$root = (Resolve-Path -Path "$PSScriptRoot\..").Path
$scriptDir = Join-Path $root 'scripts'
$pluginDir = Join-Path $root 'plugins'
$contextDir = Join-Path $root 'chat_context'

# Thresholds - adjust these to tune sensitivity
$config = @{
  MaxFileSizeKB = 50           # Warn if file exceeds this size
  MaxFileLines = 500           # Warn if file exceeds this line count
  MaxFunctionLines = 80        # Warn if function body exceeds this
  MaxCyclomaticComplexity = 10 # Reserved for future complexity analysis
  MaxDuplicateThreshold = 5    # Min lines to consider as duplicate block
  StaleArchiveDays = 90        # Warn about very old archives
  StaleTodoDays = 30           # Reserved for TODO freshness check
}

# Load centralized project config if present and override relevant keys
$projCfgPath = Join-Path $PSScriptRoot 'lib\ProjectConfig.ps1'
if (Test-Path $projCfgPath) {
  . $projCfgPath
  if ($null -ne $ProjectConfig.Duplicate.MinLines) { $config.MaxDuplicateThreshold = $ProjectConfig.Duplicate.MinLines }
}

# Global excludes (used when enumerating files in checks). Populated from ProjectConfig if present.
$GlobalExcludes = @()
if ($null -ne $ProjectConfig -and $null -ne $ProjectConfig.Duplicate.ExcludePaths) { $GlobalExcludes = $ProjectConfig.Duplicate.ExcludePaths }

# Override other thresholds from ProjectConfig if present
if ($null -ne $ProjectConfig) {
  if ($null -ne $ProjectConfig.FileHygiene.MaxFileSizeKB) { $config.MaxFileSizeKB = $ProjectConfig.FileHygiene.MaxFileSizeKB }
  if ($null -ne $ProjectConfig.FileHygiene.MaxFileLines) { $config.MaxFileLines = $ProjectConfig.FileHygiene.MaxFileLines }
  if ($null -ne $ProjectConfig.PowerShell.MaxFunctionLines) { $config.MaxFunctionLines = $ProjectConfig.PowerShell.MaxFunctionLines }
}

# === Results accumulator ===
# All findings are stored here, then rendered at the end based on -Report format
# Severity levels: error (blocking), warning (should fix), info (optional)
$script:Results = @{
  Scope = $Scope
  Timestamp = (Get-Date).ToString('o')
  Summary = @{ Errors = 0; Warnings = 0; Info = 0; Fixed = 0 }
  Checks = @()
}

# Helper: Add a finding to results and increment counters
function Add-Finding {
  param(
    [string]$Category,
    [string]$Severity,  # error, warning, info
    [string]$File,
    [int]$Line = 0,
    [string]$Message,
    [string]$Suggestion = '',
    [bool]$Fixed = $false
  )
  
  $script:Results.Checks += [PSCustomObject]@{
    Category   = $Category
    Severity   = $Severity
    File       = $File -replace [regex]::Escape($root), '.'
    Line       = $Line
    Message    = $Message
    Suggestion = $Suggestion
    Fixed      = $Fixed
  }
  
  switch ($Severity) {
    'error'   { $script:Results.Summary.Errors++ }
    'warning' { $script:Results.Summary.Warnings++ }
    'info'    { $script:Results.Summary.Info++ }
  }
  if ($Fixed) { $script:Results.Summary.Fixed++ }
}

# ============================================================
# CHECK FUNCTIONS
# Each function checks a specific aspect of project health.
# They call Add-Finding() to record issues.
# ============================================================

# --- Test-FileHygiene ---
# Checks: file size, line count, BOM presence, mixed line endings
# Used by: all scopes (scripts, plugins, context)
function Test-FileHygiene {
  param([string]$Path, [string]$Category)
  
  # Determine include extensions from ProjectConfig if present
  $includes = @('*.ps1','*.md','*.java','*.kt','*.yml','*.json')
  if ($null -ne $ProjectConfig -and $null -ne $ProjectConfig.FileHygiene.Extensions) {
    $includes = $ProjectConfig.FileHygiene.Extensions | ForEach-Object { "*$_" }
  }

  $files = Get-ChildItem -Path $Path -Recurse -File -Include $includes -ErrorAction SilentlyContinue

  # Apply global excludes (path prefixes)
  $excludeFulls = @()
  foreach ($ex in $GlobalExcludes) { $excludeFulls += (Join-Path $root $ex) }
  if ($excludeFulls.Count -gt 0) {
    $files = $files | Where-Object {
      $skip = $false
      foreach ($exFull in $excludeFulls) { if ($_.FullName -like "$exFull*") { $skip = $true; break } }
      -not $skip
    }
  }
  
  foreach ($f in $files) {
    $relPath = $f.FullName
    
    # Size check
    $sizeKB = [math]::Round($f.Length / 1024, 1)
    if ($sizeKB -gt $config.MaxFileSizeKB) {
      Add-Finding -Category $Category -Severity 'warning' -File $relPath `
        -Message "File size ${sizeKB}KB exceeds ${($config.MaxFileSizeKB)}KB threshold" `
        -Suggestion "Consider splitting or archiving old content"
    }
    
    # Line count check
    try {
      $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
      $lineCount = ($content -split '\r?\n').Count
      
      if ($lineCount -gt $config.MaxFileLines) {
        Add-Finding -Category $Category -Severity 'warning' -File $relPath `
          -Message "File has $lineCount lines (threshold: $($config.MaxFileLines))" `
          -Suggestion "Consider refactoring into smaller modules"
      }
      
      # BOM check (non-UTF8-BOM for scripts is preferred)
      $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
      if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        if ($f.Extension -eq '.ps1') {
          Add-Finding -Category $Category -Severity 'info' -File $relPath `
            -Message "Has UTF-8 BOM (acceptable for PowerShell)" `
            -Suggestion "No action needed"
        }
      }
      
      # Mixed line endings check
      $hasCRLF = $content -match '\r\n'
      $hasLF = $content -match '(?<!\r)\n'
      if ($hasCRLF -and $hasLF) {
        Add-Finding -Category $Category -Severity 'warning' -File $relPath `
          -Message "Mixed line endings (CRLF and LF)" `
          -Suggestion "Normalize to consistent line endings"
      }
    } catch {
      Add-Finding -Category $Category -Severity 'error' -File $relPath `
        -Message "Failed to read file: $($_.Exception.Message)"
    }
  }
}

# --- Test-PowerShellQuality ---
# Checks: function length, duplicate code blocks, TODO/FIXME comments, hardcoded paths
# PowerShell-specific quality checks for scripts/*.ps1
function Test-PowerShellQuality {
  param([string]$Path)
  
  $scripts = Get-ChildItem -Path $Path -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue
  # Apply global excludes (path prefixes)
  $excludeFulls = @()
  foreach ($ex in $GlobalExcludes) { $excludeFulls += (Join-Path $root $ex) }
  if ($excludeFulls.Count -gt 0) {
    $scripts = $scripts | Where-Object {
      $skip = $false
      foreach ($exFull in $excludeFulls) { if ($_.FullName -like "$exFull*") { $skip = $true; break } }
      -not $skip
    }
  }
  
  foreach ($script in $scripts) {
    $content = Get-Content -LiteralPath $script.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    
    $relPath = $script.FullName
    
    # Function length check
    $functionPattern = [regex]'(?ms)^function\s+([A-Za-z0-9_-]+)\s*\{(.+?)^\}'
    $matches = $functionPattern.Matches($content)
    foreach ($m in $matches) {
      $funcName = $m.Groups[1].Value
      $funcBody = $m.Groups[2].Value
      $funcLines = ($funcBody -split '\r?\n').Count
      
      if ($funcLines -gt $config.MaxFunctionLines) {
        $lineNum = ($content.Substring(0, $m.Index) -split '\r?\n').Count
        Add-Finding -Category 'scripts' -Severity 'warning' -File $relPath -Line $lineNum `
          -Message "Function '$funcName' has $funcLines lines (threshold: $($config.MaxFunctionLines))" `
          -Suggestion "Consider breaking into smaller helper functions"
      }
    }
    
    # Duplicate code detection (simple: repeated multi-line blocks)
    $lines = $content -split '\r?\n'
    $blocks = @{}
    for ($i = 0; $i -lt $lines.Count - $config.MaxDuplicateThreshold; $i++) {
      $block = ($lines[$i..($i + $config.MaxDuplicateThreshold - 1)] | Where-Object { $_ -match '\S' }) -join '|'
      if ($block.Length -gt 50) {  # Only consider substantial blocks
        if ($blocks.ContainsKey($block)) {
          $blocks[$block]++
        } else {
          $blocks[$block] = 1
        }
      }
    }
    $duplicates = $blocks.GetEnumerator() | Where-Object { $_.Value -gt 1 }
    if ($duplicates.Count -gt 0) {
      Add-Finding -Category 'scripts' -Severity 'info' -File $relPath `
        -Message "Found $($duplicates.Count) repeated code blocks ($($config.MaxDuplicateThreshold)+ lines)" `
        -Suggestion "Consider extracting to shared functions"
    }
    
    # Stale TODO/FIXME check
    $todoPattern = [regex]'#\s*(TODO|FIXME|HACK|XXX)[:\s](.+?)$'
    $todoMatches = $todoPattern.Matches($content)
    if ($todoMatches.Count -gt 0) {
      Add-Finding -Category 'scripts' -Severity 'info' -File $relPath `
        -Message "Found $($todoMatches.Count) TODO/FIXME comments" `
        -Suggestion "Review and resolve or document in open-questions"
    }
    
    # Hardcoded paths check
    $pathPattern = [regex]'C:\\Users\\[^\\]+\\'
    if ($content -match $pathPattern) {
      $lineNum = 0
      $contentLines = $content -split '\r?\n'
      for ($i = 0; $i -lt $contentLines.Count; $i++) {
        if ($contentLines[$i] -match $pathPattern) {
          $lineNum = $i + 1
          break
        }
      }
      Add-Finding -Category 'scripts' -Severity 'warning' -File $relPath -Line $lineNum `
        -Message "Contains hardcoded user path" `
        -Suggestion "Use relative paths or environment variables"
    }
  }
}

# --- Test-DuplicateContent ---
# Runs the external scan_duplicates.ps1 and ingests its JSON report
function Test-DuplicateContent {
  param(
    [string[]]$IncludePaths = @('chat_context','scripts'),
    [string]$Category = 'project'
  )

  Write-Host "  Running duplicate content scanner for: $($IncludePaths -join ', ')" -ForegroundColor Gray

  $includeArg = $IncludePaths -join ','
  try {
    # Prefer calling shared library function if available
    $dupLib = Join-Path $PSScriptRoot 'lib\\DuplicateContent.ps1'
    if (Test-Path $dupLib) {
      . $dupLib
      # Use excludes from project config if available
      $excludes = @()
      if ($null -ne $ProjectConfig -and $null -ne $ProjectConfig.Duplicate.ExcludePaths) { $excludes = $ProjectConfig.Duplicate.ExcludePaths }
      $dups = Get-DuplicateBlocks -RootPath $root -IncludePaths $IncludePaths -MinLines $config.MaxDuplicateThreshold -Extensions @('.md','.ps1') -ExcludePaths $excludes
      if ($null -ne $dups) {
        try {
          $jsonPath = Write-DuplicateReport -Duplicates $dups -OutDir (Join-Path $scriptDir 'audit-data') -Prefix 'duplicates'
        } catch {
          Add-Finding -Category $Category -Severity 'warning' -File $root `
            -Message "Failed to write duplicates report: $($_.Exception.Message)" `
            -Suggestion "Check Write-DuplicateReport implementation and output directory"
          $jsonPath = $null
        }
      } else {
        # No duplicates data returned; fall back to running external scanner to produce a report
        & "$PSScriptRoot\scan_duplicates.ps1" -RootPath $root -IncludePaths $includeArg -MinLines $config.MaxDuplicateThreshold -Extensions ".md,.ps1" 2>&1 | Out-Null
        $jsonPath = $null
      }
    } else {
      # Run the scanner script (it writes a JSON report into scripts/audit-data)
      & "$PSScriptRoot\scan_duplicates.ps1" -RootPath $root -IncludePaths $includeArg -MinLines $config.MaxDuplicateThreshold -Extensions ".md,.ps1" 2>&1 | Out-Null
    }
  } catch {
    Add-Finding -Category $Category -Severity 'warning' -File $root `
      -Message "Duplicate scanner execution failed: $($_.Exception.Message)" `
      -Suggestion "Ensure scan_duplicates.ps1 is present and executable"
    return
  }

  $auditDir = Join-Path $scriptDir 'audit-data'
  if (-not (Test-Path $auditDir)) {
    Add-Finding -Category $Category -Severity 'warning' -File $root `
      -Message "Duplicate scanner did not produce an audit-data directory" `
      -Suggestion "Check scan_duplicates.ps1 output"
    return
  }

  if (-not $jsonPath) {
    $jsonFile = Get-ChildItem -Path $auditDir -File -Filter 'duplicates-*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  } else {
    $jsonFile = Get-Item -LiteralPath $jsonPath -ErrorAction SilentlyContinue
  }
  if (-not $jsonFile) {
    Add-Finding -Category $Category -Severity 'info' -File $root `
      -Message "No duplicates report found after scanner run" `
      -Suggestion "Run scan_duplicates.ps1 manually to debug"
    return
  }

  $script:Results.DuplicatesReport = $jsonFile.FullName

  try {
    $dups = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json
  } catch {
    Add-Finding -Category $Category -Severity 'warning' -File $jsonFile.FullName `
      -Message "Failed to parse duplicates JSON: $($_.Exception.Message)" `
      -Suggestion "Inspect $($jsonFile.FullName)"
    return
  }

  # Suggest centralization opportunities based on duplicates
  if ($dups -and $dups.Count -gt 0) {
    Test-CentralizationOpportunities -Duplicates $dups -RootPath $root -Category $Category
  }

  if (-not $dups -or $dups.Count -eq 0) {
    Add-Finding -Category $Category -Severity 'info' -File $jsonFile.FullName `
      -Message "No duplicated blocks found (MinLines: $($config.MaxDuplicateThreshold))" `
      -Suggestion "Increase sensitivity by lowering MinLines if desired"
    return
  }

# Record the active project config used by this run for onboarding/traceability
if ($null -ne $ProjectConfig) {
  $script:Results.ConfigUsed = $ProjectConfig
} else {
  $script:Results.ConfigUsed = @{ Thresholds = $config; GlobalExcludes = $GlobalExcludes }
}

  foreach ($d in $dups) {
    $count = $d.Count
    $severity = if ($count -ge 3) { 'warning' } else { 'info' }
    $firstInst = $d.Instances[0]
    $message = "$count occurrences of a duplicated block (hash $($d.Hash)) - sample at $([IO.Path]::GetFileName($firstInst.File)):$($firstInst.Line)"
    $suggest = "See duplicates report: $($jsonFile.Name)"
    Add-Finding -Category $Category -Severity $severity -File $jsonFile.FullName -Line 0 -Message $message -Suggestion $suggest
  }
}


# --- Test-CentralizationOpportunities ---
# Detects duplicated blocks that would benefit from being extracted into a shared library
function Test-CentralizationOpportunities {
  param(
    [Parameter(Mandatory=$true)][object]$Duplicates,
    [Parameter(Mandatory=$true)][string]$RootPath,
    [string]$Category = 'project'
  )

  $occThresh = 3
  $distinctFileThresh = 2
  if ($null -ne $ProjectConfig) {
    if ($null -ne $ProjectConfig.Duplicate.CentralizeOccurrenceThreshold) { $occThresh = $ProjectConfig.Duplicate.CentralizeOccurrenceThreshold }
    if ($null -ne $ProjectConfig.Duplicate.CentralizeDistinctFileThreshold) { $distinctFileThresh = $ProjectConfig.Duplicate.CentralizeDistinctFileThreshold }
  }

  foreach ($d in $Duplicates) {
    $instances = $d.Instances
    $files = $instances | ForEach-Object { $_.File } | ForEach-Object { $_ -replace [regex]::Escape($RootPath), '.' }
    $uniqueFiles = $files | Sort-Object -Unique

    # Count distinct files excluding ones already under scripts/lib
    $distinctTargets = $uniqueFiles | Where-Object { $_ -notmatch '\\scripts\\lib\\' }
    if ($d.Count -ge $occThresh -and $distinctTargets.Count -ge $distinctFileThresh) {
      $sample = $uniqueFiles[0]
      $suggestPath = Join-Path 'scripts/lib' "extracted-duplicate-$($d.Hash).ps1"
      $msg = "$($d.Count) occurrences across $($uniqueFiles.Count) files. Consider extracting to $suggestPath"
      $filesList = ($distinctTargets -join ', ')
      Add-Finding -Category $Category -Severity 'info' -File $sample -Line 0 `
        -Message "Centralization opportunity: $msg" `
        -Suggestion "Instances: $filesList. Suggest extracting to $suggestPath"
    }
  }
}

# --- Test-PluginQuality ---
# Checks: build.gradle existence, plugin.yml, README, unused imports
# Java/Kotlin plugin-specific checks for plugins/*/
function Test-PluginQuality {
  param([string]$Path)
  
  if (-not (Test-Path $Path)) { return }
  
  $plugins = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
  
  foreach ($plugin in $plugins) {
    $pluginPath = $plugin.FullName
    $pluginName = $plugin.Name
    
    # Check for build.gradle or build.gradle.kts
    $hasBuildFile = (Test-Path (Join-Path $pluginPath 'build.gradle')) -or 
                    (Test-Path (Join-Path $pluginPath 'build.gradle.kts'))
    if (-not $hasBuildFile) {
      Add-Finding -Category 'plugins' -Severity 'error' -File $pluginPath `
        -Message "Plugin '$pluginName' missing build.gradle" `
        -Suggestion "Add Gradle build configuration"
    }
    
    # Check for plugin.yml
    $pluginYml = Join-Path $pluginPath 'src\main\resources\plugin.yml'
    if (-not (Test-Path $pluginYml)) {
      Add-Finding -Category 'plugins' -Severity 'error' -File $pluginPath `
        -Message "Plugin '$pluginName' missing plugin.yml" `
        -Suggestion "Add plugin.yml to src/main/resources"
    }
    
    # Check for README
    $hasReadme = (Test-Path (Join-Path $pluginPath 'README.md')) -or
                 (Test-Path (Join-Path $pluginPath 'readme.md'))
    if (-not $hasReadme) {
      Add-Finding -Category 'plugins' -Severity 'info' -File $pluginPath `
        -Message "Plugin '$pluginName' missing README" `
        -Suggestion "Add README.md with usage documentation"
    }
    
    # Check source files
    $srcDir = Join-Path $pluginPath 'src\main'
    if (Test-Path $srcDir) {
      Test-FileHygiene -Path $srcDir -Category 'plugins'
      
      # Java/Kotlin specific checks
      $sourceFiles = Get-ChildItem -Path $srcDir -Recurse -File -Include '*.java','*.kt' -ErrorAction SilentlyContinue
      foreach ($src in $sourceFiles) {
        $content = Get-Content -LiteralPath $src.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # Unused imports (basic check)
        $importPattern = [regex]'import\s+([A-Za-z0-9_.]+);'
        $imports = $importPattern.Matches($content)
        foreach ($imp in $imports) {
          $className = ($imp.Groups[1].Value -split '\.')[-1]
          # Check if class name appears elsewhere in file (very basic)
          $usagePattern = [regex]"\b$className\b"
          $usages = $usagePattern.Matches($content)
          if ($usages.Count -le 1) {  # Only the import itself
            Add-Finding -Category 'plugins' -Severity 'info' -File $src.FullName `
              -Message "Potentially unused import: $($imp.Groups[1].Value)" `
              -Suggestion "Remove if not needed"
          }
        }
      }
    }
  }
}

# --- Get-OpenQuestionsSummary ---
# Parses open-questions-context.md and returns counts by status/priority
# Used by: Hygiene Prompts section to show question triage status
function Get-OpenQuestionsSummary {
  param([string]$Path)
  
  $questionsFile = Join-Path $Path 'open-questions-context.md'
  if (-not (Test-Path $questionsFile)) { return $null }
  
  $content = Get-Content -LiteralPath $questionsFile -Raw -ErrorAction SilentlyContinue
  if (-not $content) { return $null }
  
  $summary = @{
    Open = 0
    OpenHigh = 0
    OpenLow = 0
    Deferred = 0
    Total = 0
    OldestOpen = $null
    Questions = @()
  }
  
  # Parse questions with status
  $lines = $content -split '\r?\n'
  $currentSection = ''
  
  foreach ($line in $lines) {
    if ($line -match '^##\s+(.+)') {
      $currentSection = $Matches[1].Trim()
      continue
    }
    
    if ($line -match '^\s*-\s+(.+?)<!--\s*status:\s*(open|deferred|resolved)') {
      $questionText = $Matches[1].Trim()
      $status = $Matches[2].ToLower()
      
      $priority = 'normal'
      if ($line -match 'priority:\s*(high|low)') {
        $priority = $Matches[1].ToLower()
      }
      
      $summary.Total++
      
      switch ($status) {
        'open' {
          $summary.Open++
          if ($priority -eq 'high') { $summary.OpenHigh++ }
          elseif ($priority -eq 'low') { $summary.OpenLow++ }
          
          $summary.Questions += [PSCustomObject]@{
            Section = $currentSection
            Text = $questionText
            Status = $status
            Priority = $priority
          }
        }
        'deferred' { $summary.Deferred++ }
      }
    }
  }
  
  return $summary
}

# --- Get-PhilosophyAge ---
# Returns days since general-chat-context.md was modified
# Used by: Hygiene Prompts to detect stale philosophy (quarterly review trigger)
function Get-PhilosophyAge {
  param([string]$Path)
  
  $generalFile = Join-Path $Path 'general-chat-context.md'
  if (-not (Test-Path $generalFile)) { return $null }
  
  # Get file's last modification time as a proxy for philosophy update
  $file = Get-Item -LiteralPath $generalFile
  $daysSinceModified = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalDays)
  
  return $daysSinceModified
}

# --- Test-ContextHealth ---
# Checks: file hygiene, archive staleness, (Memory File) headers, pointer integrity
# Context-specific checks for chat_context/*.md
function Test-ContextHealth {
  param([string]$Path)
  
  if (-not (Test-Path $Path)) { return }
  
  # File hygiene
  Test-FileHygiene -Path $Path -Category 'context'
  
  # Archive staleness
  $archiveDir = Join-Path $Path 'archives'
  if (Test-Path $archiveDir) {
    $archives = Get-ChildItem -Path $archiveDir -File -Filter '*.md' -ErrorAction SilentlyContinue
    $cutoff = (Get-Date).AddDays(-$config.StaleArchiveDays)
    
    foreach ($arch in $archives) {
      if ($arch.LastWriteTime -lt $cutoff) {
        Add-Finding -Category 'context' -Severity 'info' -File $arch.FullName `
          -Message "Archive is $([math]::Round(((Get-Date) - $arch.LastWriteTime).TotalDays)) days old" `
          -Suggestion "Consider compacting or removing very old archives"
      }
    }
  }
  
  # Context file health
  $contextFiles = @(
    'session-context.md',
    'reasoning-context.md',
    'changelog-context.md',
    'general-chat-context.md',
    'open-questions-context.md',
    'technical-context.md',
    'gameplay-context.md',
    'plugin-context.md'
  )
  
  foreach ($cf in $contextFiles) {
    $cfPath = Join-Path $Path $cf
    if (-not (Test-Path $cfPath)) {
      Add-Finding -Category 'context' -Severity 'info' -File $cfPath `
        -Message "Context file not found" `
        -Suggestion "Create if needed for this project"
      continue
    }
    
    $content = Get-Content -LiteralPath $cfPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    
    # Check for (Memory File) marker
    if ($content -notmatch '^\(Memory File\)') {
      Add-Finding -Category 'context' -Severity 'warning' -File $cfPath `
        -Message "Missing (Memory File) header marker" `
        -Suggestion "Add '(Memory File)' as first line for LLM context"
    }
    
    # Check for stale session markers (sessions older than 7 days still marked active)
    if ($cf -eq 'session-context.md') {
      $sessionPattern = [regex]'## Session (\d{4}-\d{2}-\d{2} \d{2}:\d{2})'
      $sessions = $sessionPattern.Matches($content)
      $cutoff = (Get-Date).AddDays(-7)
      
      foreach ($s in $sessions) {
        try {
          $sessionDate = [datetime]::ParseExact($s.Groups[1].Value, 'yyyy-MM-dd HH:mm', $null)
          if ($sessionDate -lt $cutoff) {
            # Check if this session has a close marker
            $closePattern = "Session closed.*$($s.Groups[1].Value)"
            if ($content -notmatch $closePattern) {
              Add-Finding -Category 'context' -Severity 'info' -File $cfPath `
                -Message "Session from $($s.Groups[1].Value) may be unclosed" `
                -Suggestion "Add close marker or archive old sessions"
            }
          }
        } catch { }
      }
    }
  }
  
  # Open questions triage check
  Write-Host "  Checking open questions..." -ForegroundColor Gray
  $questionsSummary = Get-OpenQuestionsSummary -Path $Path
  if ($questionsSummary -and $questionsSummary.Open -gt 0) {
    $script:Results.QuestionsSummary = $questionsSummary
    
    if ($questionsSummary.Open -gt 10) {
      Add-Finding -Category 'context' -Severity 'warning' -File (Join-Path $Path 'open-questions-context.md') `
        -Message "$($questionsSummary.Open) open questions - triage recommended" `
        -Suggestion "Review questions: mark resolved ones, defer low-priority, prioritize blockers"
    } else {
      Add-Finding -Category 'context' -Severity 'info' -File (Join-Path $Path 'open-questions-context.md') `
        -Message "$($questionsSummary.Open) open questions ($($questionsSummary.Deferred) deferred)" `
        -Suggestion "Periodic triage keeps questions actionable"
    }
  }
  
  # Philosophy age check
  Write-Host "  Checking philosophy freshness..." -ForegroundColor Gray
  $philosophyAge = Get-PhilosophyAge -Path $Path
  if ($philosophyAge -and $philosophyAge -gt 90) {
    Add-Finding -Category 'context' -Severity 'info' -File (Join-Path $Path 'general-chat-context.md') `
      -Message "Philosophy not updated in $philosophyAge days" `
      -Suggestion "Quarterly review: Do principles still reflect actual decision-making?"
  }
  $script:Results.PhilosophyAgeDays = $philosophyAge
  
  # Run pointer integrity check (call existing audit)
  Write-Host "  Running pointer integrity check..." -ForegroundColor Gray
  try {
    $auditResult = & "$PSScriptRoot\audit.ps1" 2>&1
    $auditText = $auditResult -join "`n"
    
    if ($auditText -match 'MISSING POINTERS|orphan|undefined') {
      Add-Finding -Category 'context' -Severity 'error' -File $Path `
        -Message "Pointer integrity issues found" `
        -Suggestion "Run audit.ps1 -AutoFix or manually fix broken references"
    }
  } catch {
    Add-Finding -Category 'context' -Severity 'warning' -File $Path `
      -Message "Could not run pointer audit: $($_.Exception.Message)"
  }
}

# --- Test-ReasoningQuality ---
# Conservative, rule-based reasoning critique that scans threads and writes a report.
function Test-ReasoningQuality {
  param(
    [string]$Path,
    [switch]$IncludeArchives
  )

  $libOut = Join-Path $PSScriptRoot 'audit-data'
  if (-not (Test-Path $libOut)) { New-Item -ItemType Directory -Path $libOut | Out-Null }

  try {
    Write-Host "  Running reasoning critique..." -ForegroundColor Gray
    $cfg = @{}
    if ($null -ne $ProjectConfig -and $null -ne $ProjectConfig.ReasoningCritique) { $cfg = $ProjectConfig.ReasoningCritique }

    $analyses = Scan-ReasoningCorpus -Root (Resolve-Path -Path "$PSScriptRoot\.." -ErrorAction SilentlyContinue).Path -IncludeArchives:$IncludeArchives -Config $cfg
    if ($analyses -and $analyses.Count -gt 0) {
  $report = Write-ReasoningCritiqueReport -OutDir $libOut -Data $analyses
  Add-Finding -Category 'context' -Severity 'info' -File $report.Json -Message "Reasoning critique generated" -Suggestion "See $($report.Markdown)"

      # Add summary findings: flag low scoring threads
      foreach ($a in $analyses) {
        if ($a.Score -lt 60) {
          Add-Finding -Category 'context' -Severity 'warning' -File "$Path`/$($a.Name)" -Message "Low reasoning quality (score $($a.Score))" -Suggestion "Review thread: $($a.Suggestions -join '; ')"
        } else {
          Add-Finding -Category 'context' -Severity 'info' -File "$Path`/$($a.Name)" -Message "Reasoning quality: $($a.Score)" -Suggestion "Consider summary or distillation if helpful"
        }
      }
    } else {
      Add-Finding -Category 'context' -Severity 'info' -File $Path -Message 'No reasoning threads found for critique'
    }
  } catch {
    Add-Finding -Category 'context' -Severity 'warning' -File $Path -Message "Reasoning critique failed: $($_.Exception.Message)"
  }
}

function Test-ProjectStructure {
  # Check for essential files
  $essentials = @(
    @{ Path = 'README.md'; Required = $true },
    @{ Path = 'LICENSE'; Required = $true },
    @{ Path = '.gitignore'; Required = $true },
    @{ Path = '.gitattributes'; Required = $false },
  @{ Path = 'chat_context/privacy.md'; Required = $false },
  @{ Path = 'chat_context/attachments.md'; Required = $false }
  )
  
  foreach ($e in $essentials) {
    $fullPath = Join-Path $root $e.Path
    if (-not (Test-Path $fullPath)) {
      $sev = if ($e.Required) { 'warning' } else { 'info' }
      Add-Finding -Category 'project' -Severity $sev -File $fullPath `
        -Message "Missing $($e.Path)" `
        -Suggestion "Create this file for project completeness"
    }
  }
  
  # Check for git health
  $gitDir = Join-Path $root '.git'
  if (Test-Path $gitDir) {
    # Check for uncommitted changes (informational)
    try {
      Push-Location $root
      $status = git status --porcelain 2>&1
      if ($status -and $status.Count -gt 0) {
        Add-Finding -Category 'project' -Severity 'info' -File $root `
          -Message "Git has $($status.Count) uncommitted changes" `
          -Suggestion "Commit or stash changes regularly"
      }
      Pop-Location
    } catch { }
  }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host "`n=== Lere Project Health Check ===" -ForegroundColor Cyan
Write-Host "Scope: $Scope | Report: $Report | Fix: $Fix" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

# Run checks based on scope
switch ($Scope) {
  'all' {
    Write-Host "Checking project structure..." -ForegroundColor Yellow
    Test-ProjectStructure
    
    Write-Host "Checking scripts..." -ForegroundColor Yellow
    Test-FileHygiene -Path $scriptDir -Category 'scripts'
    Test-PowerShellQuality -Path $scriptDir
  # Duplicate content scan for scripts
  Test-DuplicateContent -IncludePaths @('scripts') -Category 'scripts'
    
    Write-Host "Checking plugins..." -ForegroundColor Yellow
    Test-PluginQuality -Path $pluginDir
    
    Write-Host "Checking context files..." -ForegroundColor Yellow
    Test-ContextHealth -Path $contextDir
    # Run reasoning critique (conservative heuristics)
    if (Get-Command -Name Test-ReasoningQuality -ErrorAction SilentlyContinue) {
      Test-ReasoningQuality -Path $contextDir -IncludeArchives
    }
  # Duplicate content scan for context files
  Test-DuplicateContent -IncludePaths @('chat_context') -Category 'context'
  }
  'project' {
    Write-Host "Checking project structure..." -ForegroundColor Yellow
    Test-ProjectStructure
  }
  'scripts' {
    Write-Host "Checking scripts..." -ForegroundColor Yellow
    Test-FileHygiene -Path $scriptDir -Category 'scripts'
    Test-PowerShellQuality -Path $scriptDir
    Test-DuplicateContent -IncludePaths @('scripts') -Category 'scripts'
  }
  'plugins' {
    Write-Host "Checking plugins..." -ForegroundColor Yellow
    Test-PluginQuality -Path $pluginDir
  }
  'context' {
    Write-Host "Checking context files..." -ForegroundColor Yellow
    Test-ContextHealth -Path $contextDir
    # Run reasoning critique when checking context
    if (Get-Command -Name Test-ReasoningQuality -ErrorAction SilentlyContinue) {
      Test-ReasoningQuality -Path $contextDir -IncludeArchives
    }
    Test-DuplicateContent -IncludePaths @('chat_context') -Category 'context'
  }
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds

# ============================================================
# OUTPUT
# ============================================================

$script:Results.ElapsedSeconds = [math]::Round($elapsed, 2)

switch ($Report) {
  'json' {
    $script:Results | ConvertTo-Json -Depth 10
  }
  'markdown' {
    $md = @()
    $md += "# Health Check Report"
    $md += ""
    $md += "**Scope:** $Scope  "
    $md += "**Time:** $($script:Results.Timestamp)  "
    $md += "**Duration:** $($script:Results.ElapsedSeconds)s"
    $md += ""
    $md += "## Summary"
    $md += ""
    $md += "| Level | Count |"
    $md += "|-------|-------|"
    $md += "| Errors | $($script:Results.Summary.Errors) |"
    $md += "| Warnings | $($script:Results.Summary.Warnings) |"
    $md += "| Info | $($script:Results.Summary.Info) |"
    if ($Fix) { $md += "| Fixed | $($script:Results.Summary.Fixed) |" }
    $md += ""
    
    if ($script:Results.Checks.Count -gt 0) {
      $md += "## Findings"
      $md += ""
      
      $grouped = $script:Results.Checks | Group-Object Category
      foreach ($g in $grouped) {
        $md += "### $($g.Name)"
        $md += ""
        foreach ($c in $g.Group) {
          $icon = switch ($c.Severity) { 'error' { '❌' } 'warning' { '⚠️' } 'info' { 'ℹ️' } }
          $md += "- $icon **$($c.File)**$(if ($c.Line) { ":$($c.Line)" }): $($c.Message)"
          if ($c.Suggestion) { $md += "  - _$($c.Suggestion)_" }
        }
        $md += ""
      }
    }
    
    $md -join "`n"
  }
  'console' {
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor White
    
    $errColor = if ($script:Results.Summary.Errors -gt 0) { 'Red' } else { 'Green' }
    $warnColor = if ($script:Results.Summary.Warnings -gt 0) { 'Yellow' } else { 'Green' }
    
    Write-Host "  Errors:   $($script:Results.Summary.Errors)" -ForegroundColor $errColor
    Write-Host "  Warnings: $($script:Results.Summary.Warnings)" -ForegroundColor $warnColor
    Write-Host "  Info:     $($script:Results.Summary.Info)" -ForegroundColor Cyan
    if ($Fix) {
      Write-Host "  Fixed:    $($script:Results.Summary.Fixed)" -ForegroundColor Green
    }
    Write-Host "  Duration: $($script:Results.ElapsedSeconds)s" -ForegroundColor Gray
    Write-Host ""
    
    if ($script:Results.Checks.Count -gt 0) {
      $grouped = $script:Results.Checks | Group-Object Category
      foreach ($g in $grouped) {
        Write-Host "--- $($g.Name) ---" -ForegroundColor White
        foreach ($c in ($g.Group | Sort-Object Severity)) {
          $color = switch ($c.Severity) { 'error' { 'Red' } 'warning' { 'Yellow' } 'info' { 'Cyan' } }
          $prefix = switch ($c.Severity) { 'error' { '[ERR]' } 'warning' { '[WRN]' } 'info' { '[INF]' } }
          
          Write-Host "  $prefix " -NoNewline -ForegroundColor $color
          Write-Host "$($c.File)$(if ($c.Line) { ":$($c.Line)" })" -NoNewline -ForegroundColor White
          Write-Host " - $($c.Message)" -ForegroundColor Gray
          
          if ($c.Suggestion -and $Verbose) {
            Write-Host "         -> $($c.Suggestion)" -ForegroundColor DarkGray
          }
        }
        Write-Host ""
      }
    } else {
      Write-Host "No issues found!" -ForegroundColor Green
    }
    
    # Hygiene prompts section
    Write-Host ""
    Write-Host "=== Hygiene Prompts ===" -ForegroundColor Magenta
    Write-Host ""
    
    # Philosophy check
    if ($null -ne $script:Results.PhilosophyAgeDays) {
      $age = $script:Results.PhilosophyAgeDays
      if ($age -gt 90) {
        Write-Host "  [REVIEW] Philosophy last updated $age days ago" -ForegroundColor Yellow
        Write-Host "           -> Do principles still reflect actual decision-making?" -ForegroundColor DarkGray
      } elseif ($age -gt 30) {
        Write-Host "  [OK] Philosophy updated $age days ago" -ForegroundColor Green
      } else {
        Write-Host "  [OK] Philosophy recently updated ($age days ago)" -ForegroundColor Green
      }
    } else {
      Write-Host "  [??] Philosophy age unknown" -ForegroundColor Gray
    }
    
    # Questions triage
    if ($script:Results.QuestionsSummary) {
      $qs = $script:Results.QuestionsSummary
      if ($qs.Open -gt 10) {
        Write-Host "  [TRIAGE] $($qs.Open) open questions need review" -ForegroundColor Yellow
        Write-Host "           -> Mark resolved, defer low-priority, prioritize blockers" -ForegroundColor DarkGray
      } elseif ($qs.Open -gt 0) {
        Write-Host "  [OK] $($qs.Open) open questions ($($qs.Deferred) deferred)" -ForegroundColor Green
      } else {
        Write-Host "  [OK] No open questions" -ForegroundColor Green
      }
      
      if ($qs.OpenHigh -gt 0) {
        Write-Host "        High priority: $($qs.OpenHigh)" -ForegroundColor Red
      }
    } else {
      Write-Host "  [??] Questions not checked" -ForegroundColor Gray
    }
    
    # Bloat check summary - look for line count or size warnings
    $bloatFindings = @($script:Results.Checks | Where-Object { 
      $_.Message -match 'lines \(' -or $_.Message -match 'size.*KB' -or $_.Message -match 'exceeds.*threshold'
    })
    if ($bloatFindings.Count -gt 0) {
      Write-Host "  [BLOAT] $($bloatFindings.Count) file(s) over size/line threshold" -ForegroundColor Yellow
      foreach ($bf in $bloatFindings) {
        Write-Host "          - $($bf.File): $($bf.Message)" -ForegroundColor DarkYellow
      }
      Write-Host "          -> Consider archiving or splitting" -ForegroundColor DarkGray
    } else {
      Write-Host "  [OK] No bloated files" -ForegroundColor Green
    }
    
    Write-Host ""
  }
}

# Exit with error code if errors found
if ($script:Results.Summary.Errors -gt 0) {
  exit 1
}
exit 0
