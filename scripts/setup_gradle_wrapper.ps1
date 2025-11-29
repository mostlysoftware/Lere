<#
Generates a Gradle wrapper for the repository if Gradle is available locally.

Usage (PowerShell):
  # Run from repository root
  .\scripts\setup_gradle_wrapper.ps1

This script will:
 - Check for `gradle` on PATH.
 - If found, run `gradle wrapper --gradle-version 8.4.1` to generate wrapper files.
 - Print next steps to commit the generated wrapper files (`gradlew`, `gradlew.bat`, `gradle/wrapper/*`).

Note: If you don't have Gradle locally, install it (e.g., Chocolatey: `choco install gradle -y`) or use a machine that has Gradle.
#>

param(
    [string]$GradleVersion = '8.4.1'
)

 
# Use shared logging helpers and start run log
. "$PSScriptRoot\lib\logging.ps1"
$root = (Resolve-Path -Path "$PSScriptRoot\..").Path
Start-RunLog -Root $root -ScriptName 'setup_gradle_wrapper' -Note "Gradle wrapper setup"
try {
    # Prefer shared helper if present; fall back to local definition for compatibility
    $shared = Join-Path $PSScriptRoot 'lib\Test-CommandExists.ps1'
    if (Test-Path $shared) {
        . $shared
    } else {
        function Test-CommandExists {
            param([string]$Cmd)
            return (Get-Command $Cmd -ErrorAction SilentlyContinue) -ne $null
        }
    }

    Write-Info "Setting up Gradle wrapper (preferred Gradle version: $GradleVersion)"

    if (-not (Test-CommandExists -Cmd 'gradle')) {
        Write-Warn "Gradle is not available on PATH. Please install Gradle or run this script on a machine with Gradle."
        Write-Info "Suggested install on Windows (Chocolatey):  choco install gradle -y"
        exit 2
    }

    Write-Info "Gradle found. Generating wrapper..."

    # Run gradle wrapper at repo root
    & gradle wrapper --gradle-version $GradleVersion

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Gradle wrapper generation failed (exit $LASTEXITCODE)."
        exit $LASTEXITCODE
    }

    Write-Info "Gradle wrapper generated successfully."
    Write-Info "Next steps (commit these files):"
    Write-Info "  gradlew"
    Write-Info "  gradlew.bat"
    Write-Info "  gradle/wrapper/gradle-wrapper.jar"
    Write-Info "  gradle/wrapper/gradle-wrapper.properties"
    Write-Info "Then you can run builds via: .\gradlew.bat -p plugins\lere_core build"

    exit 0
} finally {
    try { Save-RunLogToSummaries -Root $root } catch { }
}
