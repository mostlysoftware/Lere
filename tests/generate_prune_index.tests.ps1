Describe 'generate_prune_index' {
    It 'generates an index.md from existing proposal manifests and summaries' {
        $testsRoot = $PSScriptRoot
        $repoRoot = (Resolve-Path (Join-Path $testsRoot '..')).Path
        $manifestsDir = Join-Path $repoRoot 'scripts\audit-data\manifests'
        New-Item -ItemType Directory -Path $manifestsDir -Force | Out-Null

        $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $manifestPath = Join-Path $manifestsDir "prune-proposal-$ts-testindex.json"
        $mdPath = [System.IO.Path]::ChangeExtension($manifestPath, '.md')

        $item = [pscustomobject]@{
            Path = (Join-Path $manifestsDir 'dummy.txt')
            Length = 10
            LastWriteTimeUtc = (Get-Date).ToUniversalTime().ToString('o')
            SHA256 = 'deadbeef'
        }
        $manifest = [pscustomobject]@{
            Operator = $env:USERNAME
            Timestamp = (Get-Date).ToUniversalTime().ToString('o')
            RuleId = 'testindex'
            Items = @($item)
        }
        $manifest | ConvertTo-Json -Depth 6 | Out-File -FilePath $manifestPath -Encoding UTF8
        "# Summary`n- Items: 1" | Out-File -FilePath $mdPath -Encoding UTF8

        # run generator
        . (Resolve-Path (Join-Path $repoRoot 'scripts\generate_prune_index.ps1')).Path -ManifestsDir $manifestsDir -OutFile (Join-Path $manifestsDir 'index.md')

        $index = Join-Path $manifestsDir 'index.md'
    (Test-Path $index) | Should Be $true
    (Get-Content -Path $index -Raw) | Should Match 'testindex'

        # cleanup safely
        if (Test-Path $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $mdPath) { Remove-Item -LiteralPath $mdPath -Force -ErrorAction SilentlyContinue }
        $tries = 0
        while ($tries -lt 6 -and (Test-Path $index)) {
            try {
                Remove-Item -LiteralPath $index -Force -ErrorAction Stop
                break
            } catch {
                $tries++
                Start-Sleep -Milliseconds (200 * $tries)
            }
        }
    }
}
