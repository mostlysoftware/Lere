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

Write-Host "Setting up Gradle wrapper (preferred Gradle version: $GradleVersion)" -ForegroundColor Cyan

if (-not (Test-CommandExists -Cmd 'gradle')) {
    Write-Host "Gradle is not available on PATH. Please install Gradle or run this script on a machine with Gradle." -ForegroundColor Yellow
    Write-Host "Suggested install on Windows (Chocolatey):  choco install gradle -y" -ForegroundColor DarkGray
    exit 2
}

Write-Host "Gradle found. Generating wrapper..." -ForegroundColor Green

# Run gradle wrapper at repo root
& gradle wrapper --gradle-version $GradleVersion

if ($LASTEXITCODE -ne 0) {
    Write-Host "Gradle wrapper generation failed (exit $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Gradle wrapper generated successfully." -ForegroundColor Green
Write-Host "Next steps (commit these files):" -ForegroundColor Cyan
Write-Host "  gradlew" -ForegroundColor DarkGray
Write-Host "  gradlew.bat" -ForegroundColor DarkGray
Write-Host "  gradle/wrapper/gradle-wrapper.jar" -ForegroundColor DarkGray
Write-Host "  gradle/wrapper/gradle-wrapper.properties" -ForegroundColor DarkGray
Write-Host "Then you can run builds via: .\gradlew.bat -p plugins\lere_core build" -ForegroundColor Cyan

exit 0
