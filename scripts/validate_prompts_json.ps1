. $PSScriptRoot\\lib\\logging.ps1
# Expected schema: array of objects with either 'prompt' (preferred) or 'text' (legacy), 'tag', 'source', and 'created_at' or 'added_at'

param(
    [string]$File = 'chat_context/pending_prompts.json'
)

Write-Info "Validating prompts JSON file: $File"
if (-not (Test-Path $File)) {
    Write-Error "File not found: $File"
    exit 2
}

try {
    $raw = Get-Content -Raw -Path $File -ErrorAction Stop
    $data = ConvertFrom-Json $raw -ErrorAction Stop
} catch {
    Write-Error "Failed to read or parse JSON: $($_.Exception.Message)"
    exit 3
}

if (-not ($data -is [System.Array])) {
    Write-Error "Expected JSON array at top level"
    exit 4
}

$allowedTags = @('idea','bug','question','task','uncategorized')

$i = 0
$texts = @{}
$errors = @()
foreach ($i in 0..($data.Count - 1)) {
    $item = $data[$i]
    $i++
    # accept either 'prompt' (preferred) or 'text' (legacy)
    if ($item.PSObject.Properties.Name -contains 'prompt') {
        $text = $item.prompt
    } elseif ($item.PSObject.Properties.Name -contains 'text') {
        $text = $item.text
    } else {
        $errors += "Entry #$i missing required field 'prompt' or 'text'"
        continue
    }

    if ($texts.ContainsKey($text)) { $errors += "Duplicate prompt text in JSON at entries $($texts[$text]) and $i" }
    else { $texts[$text] = $i }

    if ($item.PSObject.Properties.Name -contains 'tag') { $tag = [string]$item.tag } else { $tag = 'uncategorized' }
    if ($tag -ne $null) { $tag = $tag.ToLower() } else { $tag = 'uncategorized' }
    if (-not ($allowedTags -contains $tag)) { $errors += "Entry #$i has unknown tag '$tag'" }

    # accept either created_at (preferred) or added_at (legacy)
    if (-not ($item.PSObject.Properties.Name -contains 'created_at' -or $item.PSObject.Properties.Name -contains 'added_at')) {
        $errors += "Entry #$i missing 'created_at' or 'added_at' field (optional)"
    } else {
        $ts = if ($item.PSObject.Properties.Name -contains 'created_at') { $item.created_at } else { $item.added_at }
        try {
            if ($ts) { [datetime]::Parse($ts) > $null }
        } catch {
            $errors += "Entry #${i}: created_at/added_at is not a valid datetime: $ts"
        }
    }

    if (-not $item.source) { $errors += "Entry #$i missing 'source'" }
}

if ($errors.Count -gt 0) {
    Write-Error "JSON validation failed with $($errors.Count) issue(s):"
    foreach ($e in $errors) { Write-Error " - $e" }
    exit 5
}

Write-Info "JSON validation passed: $($data.Count) entries." -ForegroundColor Green
exit 0

