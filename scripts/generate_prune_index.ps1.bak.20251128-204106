<#
generate_prune_index.ps1

Scans `scripts/audit-data/manifests/` for prune proposal manifests and Markdown summaries
and generates an `index.md` file listing recent proposals with links and short previews.

Usage:
  .\scripts\generate_prune_index.ps1 -ManifestsDir 'scripts/audit-data/manifests' -OutFile 'scripts/audit-data/manifests/index.md'
#>

[CmdletBinding()]
param(
    [string] $ManifestsDir = 'scripts/audit-data/manifests',
    [string] $OutFile = 'scripts/audit-data/manifests/index.md',
    [int] $Limit = 50
)

if (-not (Test-Path $ManifestsDir)) {
    Write-Warning "Manifests directory not found: $ManifestsDir"
    return
}

$files = Get-ChildItem -Path $ManifestsDir -Filter 'prune-proposal-*.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $Limit

$sb = New-Object System.Text.StringBuilder
$sb.AppendLine('# Prune Proposals') > $null
$sb.AppendLine() > $null
$sb.AppendLine(("Generated: {0}" -f (Get-Date -Format o))) > $null
$sb.AppendLine() > $null
foreach ($f in $files) {
    try {
        $json = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
        $mdPath = [System.IO.Path]::ChangeExtension($f.FullName, '.md')
        $title = "Proposal: $($json.RuleId) - $([System.IO.Path]::GetFileNameWithoutExtension($f.Name))"
        $sb.AppendLine("## $title") > $null
        $sb.AppendLine() > $null
        $sb.AppendLine(("- Generated: {0}" -f $json.Timestamp)) > $null
        $sb.AppendLine(("- Items: {0}" -f $json.Items.Count)) > $null
        if (Test-Path $mdPath) {
            $preview = Get-Content -Path $mdPath -TotalCount 6 -ErrorAction SilentlyContinue
            $sb.AppendLine() > $null
            $sb.AppendLine('Preview:') > $null
            $sb.AppendLine('```') > $null
            $preview | ForEach-Object { $sb.AppendLine($_) > $null }
            $sb.AppendLine('```') > $null
            $sb.AppendLine() > $null
            $abs = (Resolve-Path -LiteralPath $mdPath).Path
            $cwd = (Get-Location).ProviderPath
            if ($abs.StartsWith($cwd)) { $relMd = '.' + $abs.Substring($cwd.Length) } else { $relMd = $abs }
            $sb.AppendLine(("[Open summary]($relMd)")) > $null
        } else {
            $sb.AppendLine() > $null
            $sb.AppendLine("(No markdown summary found for this proposal)") > $null
        }
        $sb.AppendLine('---') > $null
        $sb.AppendLine() > $null
    } catch {
        Write-Warning "Failed to parse manifest $($f.FullName): $($_.Exception.Message)"
    }
}

# Ensure output dir exists
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$tmp = "$OutFile.tmp"
$sb.ToString() | Out-File -FilePath $tmp -Encoding UTF8
Move-Item -Force -LiteralPath $tmp -Destination $OutFile

Write-Output $OutFile
