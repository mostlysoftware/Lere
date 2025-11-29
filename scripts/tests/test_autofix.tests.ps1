Describe 'Invoke-SemanticConsoleAutoFix' {
    It 'inserts logging, replaces console calls, and creates a backup' {
        $temp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("lere_test_autofix_$([System.Guid]::NewGuid().ToString('N'))")) -Force
        try {
            $scriptsDir = Join-Path $temp.FullName 'scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            $filePath = Join-Path $scriptsDir 'sample.ps1'
            $content = @'
Write-Host "hello"
Write-Output "out"
for ($i=0; $i -lt 100; $i++) { Write-Output $i }
'@
            Set-Content -LiteralPath $filePath -Value $content -Encoding UTF8

            # Provide minimal scaffolding expected by the autofix library
            $global:root = $temp.FullName
            $script:Results = @{ Checks = @(); Summary = @{ Errors = 0; Warnings = 0; Info = 0; Fixed = 0 } }

            function Add-Finding { param($Category,$Severity,$File,$Line,$Message,$Suggestion,$Fixed) if ($null -eq $script:Results.Checks) { $script:Results.Checks = @() } ; $script:Results.Checks += [PSCustomObject]@{ Category = $Category; Severity = $Severity; File = $File; Line = $Line; Message = $Message; Suggestion = $Suggestion; Fixed = $Fixed } }
            function Write-Info { param([string]$msg) Write-Host $msg }

            # Dot-source the extracted autofix library
            . "$PSScriptRoot\..\lib\autofix.ps1"

            Invoke-SemanticConsoleAutoFix -Path $scriptsDir

            # Assert backup exists
            $bak = Get-ChildItem -Path ($filePath + '.bak.*') -ErrorAction SilentlyContinue
            if (-not $bak) { throw 'Expected backup file to exist' }

            # Assert file content was changed to include Write-Info
            $new = Get-Content -Raw -LiteralPath $filePath
            if ($new -notmatch 'Write-Info') { throw 'Expected modified file to contain Write-Info' }
        } finally {
            Remove-Item -Recurse -Force $temp.FullName -ErrorAction SilentlyContinue
        }
    }
}
