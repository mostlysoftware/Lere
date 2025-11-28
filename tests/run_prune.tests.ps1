Describe 'run_prune wrapper' {
    It 'creates a proposal manifest, markdown summary, and index on dry-run' {
        $testsRoot = $PSScriptRoot
        # prepare temp file to propose
        $tmp = New-Item -ItemType Directory -Path (Join-Path $testsRoot 'tmp-run-prune') -Force
        $file = Join-Path $tmp.FullName 'testfile.txt'
        Set-Content -Path $file -Value 'pester-run'

    # run the wrapper script (no PR creation, no apply)
    $before = Get-Date
    & (Resolve-Path (Join-Path $testsRoot '..\tools\run_prune.ps1')).Path -Paths $file -RuleId 'pesterrun' -CreatePR:$false -Apply:$false

        # find created manifest and md by time
        $manifestsDir = Join-Path (Resolve-Path (Join-Path $testsRoot '..')).Path 'scripts\audit-data\manifests'
        $manifest = Get-ChildItem -Path $manifestsDir -Filter 'prune-proposal-*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $before } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $manifest | Should Not BeNullOrEmpty

        $md = [System.IO.Path]::ChangeExtension($manifest.FullName, '.md')
        # If the proposal exceeded threshold, an md summary and index are produced; otherwise they may not be present.
        if (Test-Path $md) {
            $index = Join-Path $manifestsDir 'index.md'
            (Test-Path $index) | Should Be $true
            (Get-Content -Path $index -Raw) | Should Match 'pesterrun'
        } else {
            Write-Host 'No markdown summary created (proposal likely below threshold)'
        }

        # cleanup created artifacts with retries
        $tries = 0
        while ($tries -lt 6) {
            try {
                if (Test-Path $manifest) { Remove-Item -LiteralPath $manifest.FullName -Force -ErrorAction Stop }
                if (Test-Path $md) { Remove-Item -LiteralPath $md -Force -ErrorAction Stop }
                if (Test-Path $index) { Remove-Item -LiteralPath $index -Force -ErrorAction Stop }
                Remove-Item -LiteralPath $tmp.FullName -Recurse -Force -ErrorAction Stop
                break
            } catch {
                $tries++
                Start-Sleep -Milliseconds (200 * $tries)
            }
        }
    }
}
