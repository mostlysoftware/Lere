<#
.SYNOPSIS
Imports prompts from a markdown file into the canonical queue, using a conservative rule: only lines that start with a blockquote `> ` are imported.

.DESCRIPTION
This script scans a markdown file (default: `chat_context/pending_prompts.md`) and extracts lines that begin with `>` (after optional leading whitespace). By default it runs in DryRun mode and writes a timestamped audit JSON file to `chat_context/.summaries/` describing what would be imported. When run without `-DryRun` it will attempt to call `Add-PromptToQueue` (from `scripts/lib/prompt_queue.ps1`) for each imported prompt if that function is available.

Note: For contributor guidance and preferred prompt format, see the top-level README -> "Contributing: prompts" and `chat_context/pending_prompts.md`.

.PARAMETER MarkdownFile
Path to the markdown file to scan. Relative paths are resolved from the repository root.
.PARAMETER DryRun
If specified (default), do not modify the repository; only write an audit and print results.
.PARAMETER AuditDir
Directory to write audit JSON files to (default: `chat_context/.summaries`). The directory will be created if it doesn't exist.
.PARAMETER Force
When present and not DryRun, force import even if `Add-PromptToQueue` is missing (it will instead append to `chat_context/pending_prompts.json`).

#>

param(
    [string]$MarkdownFile = "chat_context/pending_prompts.md",
    [switch]$DryRun,
    [string]$AuditDir = "chat_context/.summaries",
    [switch]$Force = $false
)

# Load logging helpers and start run log
. $PSScriptRoot\..\lib\logging.ps1
try { Start-RunLog -Root (Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path) -ScriptName "import_prompts_from_md" -Note "auto-applied" } catch { }

# If DryRun not explicitly provided, consult repository preferences (if available)
if (-not $PSBoundParameters.ContainsKey('DryRun')) {
    $prefPath = Join-Path $repoRoot 'scripts\tools\preferences.ps1'
    if (Test-Path $prefPath) {
        try {
            # call the preferences helper and inspect import_prompts_default_dryrun
            $prefs = & $prefPath -Action Get
            if ($prefs -and ($null -ne $prefs.import_prompts_default_dryrun)) {
                $DryRun = [bool]$prefs.import_prompts_default_dryrun
            } else {
                # fallback conservative default
                $DryRun = $true
            }
        } catch {
            # on error, default to conservative DryRun
            $DryRun = $true
        }
    } else {
        # preferences helper absent â€” keep conservative default
        $DryRun = $true
    }
}

Set-StrictMode -Version Latest

function Resolve-RepoRoot {
    # Attempt to find repository root by walking up until a .git folder is found or until root
    $p = Split-Path -Path $PSScriptRoot -Parent
    while ($p -and -not (Test-Path (Join-Path $p '.git'))) {
        $parent = Split-Path -Path $p -Parent
        if ($parent -eq $p) { break }
        $p = $parent
    }
    if (-not $p) { $p = Split-Path -Path $PSScriptRoot -Parent }
    return (Resolve-Path $p).ProviderPath
}

$repoRoot = Resolve-RepoRoot

$mdPath = if (Test-Path $MarkdownFile) { Resolve-Path $MarkdownFile } else { Resolve-Path (Join-Path $repoRoot $MarkdownFile) }
if (-not $mdPath) {
    Write-Error "Markdown file '$MarkdownFile' not found relative to repo root '$repoRoot'."
    exit 2
}

$lines = Get-Content -LiteralPath $mdPath -ErrorAction Stop

$results = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $ln = $lines[$i]
    if ($ln -match '^[ \t]*>\s*(.+)$') {
        $text = $Matches[1].Trim()
        if ($text -ne '') {
            $results += [PSCustomObject]@{
                id = [guid]::NewGuid().ToString()
                text = $text
                source = (Split-Path -Path $mdPath -NoQualifier)
                line = $i + 1
                importedOn = (Get-Date).ToString('o')
            }
        }
    }
}

if (-not (Test-Path $AuditDir)) { New-Item -ItemType Directory -Path $AuditDir -Force | Out-Null }

$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$auditFile = Join-Path $AuditDir ("import_prompts-$ts.json")

$audit = [PSCustomObject]@{
    runOn = (Get-Date).ToString('o')
    markdownFile = (Split-Path -Path $mdPath -NoQualifier)
    dryRun = [bool]$DryRun
    count = $results.Count
    prompts = $results
}

$audit | ConvertTo-Json -Depth 5 | Out-File -FilePath $auditFile -Encoding utf8

Write-Info "Import audit written to: $auditFile"
Write-Info "Found $($results.Count) prompt(s) starting with '> '."

if ($results.Count -eq 0) { exit 0 }

if ($DryRun) {
    Write-Info "DryRun enabled â€” not adding prompts to queue."
    foreach ($r in $results) { Write-Info "- [$($r.line)] $($r.text)" }
    exit 0
}

# Attempt to add to queue using Add-PromptToQueue if available
if (Get-Command -Name Add-PromptToQueue -ErrorAction SilentlyContinue) {
    Write-Info "Add-PromptToQueue found â€” adding prompts to canonical queue."
            foreach ($r in $results) {
        try {
            # Add to canonical queue using Add-PromptToQueue (expects -Prompt)
            $promptValue = if ($r.PSObject.Properties.Name -contains 'prompt') { $r.prompt } else { $r.text }
            Add-PromptToQueue -Prompt $promptValue -Author 'imported' -Root $repoRoot
            Write-Info "Added prompt (line $($r.line)): $promptValue"
        } catch {
            Write-Warning "Failed to add prompt line $($r.line): $($_.Exception.Message)"
        }
    }
    # Write a follow-up audit with importedOn
    $audit.imported = $true
    $audit.importedOn = (Get-Date).ToString('o')
    $audit | ConvertTo-Json -Depth 5 | Out-File -FilePath $auditFile -Encoding utf8
    Write-Info "Import completed; audit updated: $auditFile"
    exit 0
} else {
    Write-Warning "Add-PromptToQueue was not found."
    if ($Force) {
        # Fallback: append to chat_context/pending_prompts.json if present/valid
        $jsonPath = Join-Path $repoRoot "chat_context/pending_prompts.json"
        if (Test-Path $jsonPath) {
            try {
                $existing = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $existing = @()
            }
            $newEntries = $results | ForEach-Object {
                # create prompt-queue shaped objects so helpers and validators are consistent
                [PSCustomObject]@{
                    id = $_.id
                    prompt = $_.text
                    tag = $null
                    author = 'imported'
                    created_at = $_.importedOn
                    processed = $false
                    processed_at = $null
                    note = ''
                    source = $_.source
                }
            }
            $merged = @($existing) + $newEntries
            $merged | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8
            Write-Info "Appended $($newEntries.Count) prompts to $jsonPath"
            $audit.imported = $true
            $audit.importedOn = (Get-Date).ToString('o')
            $audit | ConvertTo-Json -Depth 5 | Out-File -FilePath $auditFile -Encoding utf8
            Write-Info "Import completed; audit updated: $auditFile"
            exit 0
        } else {
            Write-Error "Fallback requested but $jsonPath does not exist. Create the queue first or provide Add-PromptToQueue."
            exit 3
        }
    } else {
        Write-Error "Add-PromptToQueue not found and Force not specified. Aborting."
        exit 4
    }
}


