Describe 'Test-ChatContextChangePolicy' {
    It 'reports missing documentation for changed chat_context files' {
        $temp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("lere_test_policy_$([System.Guid]::NewGuid().ToString('N'))")) -Force
        Push-Location $temp.FullName
        try {
            git init -q
            New-Item -ItemType Directory -Path 'chat_context' | Out-Null
            Set-Content -Path 'chat_context/keep.md' -Value 'initial'
            git add -A; git commit -m 'initial' -q
            # Ensure the default branch is named 'main' so the policy check can reference it
            git branch -M main
            git checkout -b feature/test -q
            Set-Content -Path 'chat_context/changed.md' -Value 'update'
            git add -A; git commit -m 'add changed' -q
        } catch {
            Pop-Location
            Remove-Item -Recurse -Force $temp.FullName
            Throw "Failed to prepare test git repo: $($_.Exception.Message)"
        }
        Pop-Location

    # Initialize results store expected by Add-Finding
    $script:Results = @{ Checks = @(); Summary = @{ Errors = 0; Warnings = 0; Info = 0; Fixed = 0 } }

    # Provide a minimal Add-Finding stub so the library can record findings
    function Add-Finding { param($Category,$Severity,$File,$Line,$Message,$Suggestion,$Fixed) if ($null -eq $script:Results.Checks) { $script:Results.Checks = @() } ; $script:Results.Checks += [PSCustomObject]@{ Category = $Category; Severity = $Severity; File = $File; Line = $Line; Message = $Message; Suggestion = $Suggestion; Fixed = $Fixed } }

    # Dot-source the extracted policy library and run the policy check against the temporary repo
    . "$PSScriptRoot\..\lib\policy.ps1"
    Test-ChatContextChangePolicy -Root $temp.FullName

    $found = $script:Results.Checks | Where-Object { $_.Category -eq 'context' -and $_.Severity -eq 'error' }
    # Assert that at least one matching finding exists
    if ((($found | Measure-Object).Count -gt 0) -ne $true) { throw 'Expected at least one context error finding' }

        # cleanup
        Remove-Item -Recurse -Force $temp.FullName
    }
}
