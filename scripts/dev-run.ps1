<#
.\scripts\dev-run.ps1

Purpose: small helper to run the common dev flow on Windows PowerShell:
- run pointer audit
- build plugin projects using Gradle wrapper if present
- package the datapack into release archive

This script is intentionally conservative: it stops on errors and prints helpful guidance.
#>

param(
    [switch]$SkipAudit,
    [switch]$SkipBuild,
    [switch]$SkipDatapack
)

Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Project root: $root"

if (-not $SkipAudit) {
    Write-Host "Running pointer audit..."
    $audit = Join-Path $root 'scripts\audit.ps1'
    if (Test-Path $audit) {
        pwsh -NoProfile -ExecutionPolicy Bypass -File $audit
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Audit failed (exit $LASTEXITCODE). Fix pointers before proceeding or run with -SkipAudit.";
            exit $LASTEXITCODE
        }
    } else {
        Write-Warning "Audit script not found at $audit"
    }
}

if (-not $SkipBuild) {
    $plugins = @('plugins\lere_multiplayer','plugins\lere_core')
    foreach ($p in $plugins) {
        $proj = Join-Path $root $p
        if (-not (Test-Path $proj)) { Write-Warning "Project path missing: $proj"; continue }
        Push-Location $proj
        if (Test-Path '.\gradlew.bat') {
            Write-Host "Building $p with gradlew.bat"
            .\gradlew.bat build --quiet
        } else {
            Write-Host "Building $p with system gradle"
            gradle build --quiet
        }
        if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for $p"; Pop-Location; exit $LASTEXITCODE }
        Pop-Location
    }
}

if (-not $SkipDatapack) {
    Write-Host "Packaging datapack lere_guardian..."
    $dp = Join-Path $root 'datapacks\lere_guardian'
    $out = Join-Path $root 'release\lere_guardian_datapack.zip'
    if (-not (Test-Path $dp)) { Write-Warning "Datapack folder not found: $dp" } else {
        if (-not (Test-Path (Split-Path $out))) { New-Item -ItemType Directory -Path (Split-Path $out) | Out-Null }
        Compress-Archive -Path (Join-Path $dp '*') -DestinationPath $out -Force
        Write-Host "Datapack packaged to $out"
    }
}

Write-Host "dev-run completed successfully."
