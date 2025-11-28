Describe 'ArchiveManager basic behavior' {
    It 'creates a prune proposal manifest in dry-run' {
        $testsRoot = $PSScriptRoot
        $repoRoot = Resolve-Path (Join-Path $testsRoot '..')
        $libPath = Join-Path $repoRoot 'scripts\lib\ArchiveManager.ps1'
        . (Resolve-Path $libPath).Path

        $temp = New-Item -ItemType Directory -Path (Join-Path $testsRoot 'tmp-archive-test') -Force
        $file = Join-Path $temp.FullName 'sample.txt'
        Set-Content -Path $file -Value 'hello'

        $manifestDir = Join-Path $temp.FullName 'manifests'
        $manifest = New-ArchiveProposal -Paths $file -ManifestOutDir $manifestDir

    (Test-Path $manifest) | Should Be $true
    $content = Get-Content -Raw -Path $manifest | ConvertFrom-Json
    $content.Items.Count | Should Be 1

        # cleanup with retries (some hosts may briefly lock files)
        $tries = 0
        while ($tries -lt 6) {
            try {
                Remove-Item -LiteralPath $temp.FullName -Recurse -Force -ErrorAction Stop
                break
            } catch {
                $tries++
                Start-Sleep -Milliseconds (200 * $tries)
            }
        }
    }
}
