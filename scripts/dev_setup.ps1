<#
.SYNOPSIS
  Developer bootstrap: detect JDK/Gradle/Docker and run local plugin builds.

.DESCRIPTION
  This script helps you run builds locally without needing to install Gradle globally.
  It can download a standalone Gradle distribution into ./.dev and invoke it.
  It does not install a system JDK for you, but it detects if one is present and
  provides instructions to install if missing.

#.PARAMETER RunBuild
#  If specified, attempts to build all plugin subprojects under plugins/.
#
#.PARAMETER GradleVersion
#  Version of Gradle to download when a wrapper is not present. Default: 8.4.1
#
#.PARAMETER Force
#  Force downloading Gradle even if a local copy already exists.

.PARAMETER AutoInstallJdk
# If specified, and no JDK is found on PATH, the script will attempt to download
# a user-local (no-admin) Temurin (Adoptium) JDK into ./.dev/jdk, extract it,
# and update JAVA_HOME and PATH for the duration of the script. This is intended
# for quick local bootstraps on developer machines without admin rights. The
# download size is large (~100MB+). Use only if you consent to that download.

.PARAMETER JdkVersion
# The major JDK version to download when -AutoInstallJdk is used. Default: 17
#>
param(
  [switch]$RunBuild,
  [string]$GradleVersion = '8.4.1',
  [switch]$Force,
  [switch]$ForceJdk,
  [switch]$AutoInstallJdk,
  [switch]$SkipChecksum,
  [string]$JdkVersion = '17'
)
 
# Use shared logging helpers
. "$PSScriptRoot\lib\logging.ps1"
. "$PSScriptRoot\lib\runlog.ps1"

# Checksum helper (legacy) and thin wrapper
. "$PSScriptRoot\lib\Verify-FileChecksum.ps1"
. "$PSScriptRoot\lib\checksum.ps1"

$root = Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path
Set-Location -Path $root

# initialize per-run log
Start-RunLog -Root $root -ScriptName 'dev_setup' -Note 'Developer bootstrap'

Write-Info "Developer bootstrap starting in: $root"

 # Use extracted JDK installer helper from library
 . "$PSScriptRoot\lib\jdk-installer.ps1"

# Begin main run block so we always save run logs on exit
try {
# Check JDK
$javac = Get-Command javac -ErrorAction SilentlyContinue
if ($null -eq $javac) {
  if ($AutoInstallJdk) {
    Write-Info "JDK not found. -AutoInstallJdk provided; attempting user-local download/install (no admin)."
  $ok = Install-TemurinJdk -Version $JdkVersion -Root $root -ForceJdk:$ForceJdk -SkipChecksum:$SkipChecksum
    if (-not $ok) {
      Write-Err "Automatic JDK install failed. Please install a JDK manually or rerun with network access."
      Write-Info "Recommended manual installation options (pick one):"
      Write-Info "  - Install via winget: winget install -e --id EclipseAdoptium.Temurin.17.JDK"
      Write-Info "  - Install via Chocolatey: choco install temurin17 -y"
      Write-Info "  - Or download a JDK from https://adoptium.net/ and set JAVA_HOME and update PATH"
      Write-Info "After installing, re-run this script."
    } else {
      Write-Info "Automatic JDK install successful."
    }
    # re-check
    $javac = Get-Command javac -ErrorAction SilentlyContinue
    if ($null -ne $javac) { Write-Info "Found JDK: $($javac.Path)" }
  } else {
    Write-Warn "JDK not found in PATH (javac). You need a JDK (Java 17+) to build the plugins."
    Write-Info "Recommended installation options (pick one):"
    Write-Info "  - Install via winget: winget install -e --id EclipseAdoptium.Temurin.17.JDK"
    Write-Info "  - Install via Chocolatey: choco install temurin17 -y"
    Write-Info "  - Or download a JDK from https://adoptium.net/ and set JAVA_HOME and update PATH"
    Write-Info "After installing, re-run this script."
  }
} else {
  Write-Info "Found JDK: $($javac.Path)"
}

} finally {
  try { Save-RunLogToSummaries -Root $root } catch { }
}

# Check for gradle wrapper
$hasWrapper = (Test-Path "$root\gradlew.bat") -or (Test-Path "$root\gradlew")
if ($hasWrapper) { Write-Info "Gradle wrapper present; we'll prefer using it for builds." }

# Local gradle fallback location
$devGradleDir = Join-Path $root '.dev\gradle'
$gradleBin = $null

if (-not $hasWrapper) {
  if (-not (Test-Path $devGradleDir) -or $Force) {
    Write-Info "No gradle wrapper detected. Preparing local Gradle distribution in $devGradleDir"
    New-Item -ItemType Directory -Path $devGradleDir -Force | Out-Null
    $zipName = "gradle-$GradleVersion-bin.zip"
    $downloadUrl = "https://services.gradle.org/distributions/$zipName"
    $tmpZip = Join-Path $env:TEMP $zipName
    Write-Info "Downloading Gradle $GradleVersion from $downloadUrl"
    try {
      Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop
    } catch {
      Write-Err "Failed to download Gradle: $($_.Exception.Message)"
      exit 1
    }
    Write-Info "Extracting to $devGradleDir"
    try {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpZip, $devGradleDir)
    } catch {
      Write-Err "Extraction failed: $($_.Exception.Message)"
      exit 1
    }
    # The distribution extracts to a folder like gradle-8.4.1
    $extracted = Get-ChildItem -Path $devGradleDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($null -eq $extracted) { Write-Err "Unexpected extraction layout"; exit 1 }
    $gradleBin = Join-Path $extracted.FullName 'bin\gradle.bat'
    if (-not (Test-Path $gradleBin)) { Write-Err "gradle.bat not found in distribution"; exit 1 }
    Write-Info "Downloaded gradle to: $($extracted.FullName)"
  } else {
    $extracted = Get-ChildItem -Path $devGradleDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($null -ne $extracted) { $gradleBin = Join-Path $extracted.FullName 'bin\gradle.bat' }
    if ($null -eq $gradleBin -or -not (Test-Path $gradleBin)) {
      Write-Warn "Local gradle distribution seems missing or malformed in $devGradleDir. Use -Force to re-download."
    } else {
      Write-Info "Local gradle available at $gradleBin"
    }
  }
}

function Invoke-LocalBuild {
  param([string[]]$PluginDirs)
  foreach ($d in $PluginDirs) {
    if (-not (Test-Path $d)) { Write-Warn "Plugin dir not found: $d"; continue }
    Write-Info "Building plugin: $d"
    if (Test-Path "$root\gradlew.bat") {
      Push-Location $root
      & .\gradlew.bat -p $d clean build
      if ($LASTEXITCODE -ne 0) { Write-Err "Build failed for $d"; Pop-Location; return 1 }
      Pop-Location
    } elseif ($gradleBin -and (Test-Path $gradleBin)) {
      & "$gradleBin" -p $d clean build
      if ($LASTEXITCODE -ne 0) { Write-Err "Build failed for $d"; return 1 }
    } else {
      Write-Err "No gradle wrapper or local gradle available to run the build."
      return 1
    }
  }
  return 0
}

if ($RunBuild) {
  # Discover plugin dirs
  $pluginsRoot = Join-Path $root 'plugins'
  if (-not (Test-Path $pluginsRoot)) { Write-Err "plugins/ directory not found"; exit 1 }
  $dirs = Get-ChildItem -Path $pluginsRoot -Directory | ForEach-Object { $_.FullName }
  $status = Invoke-LocalBuild -PluginDirs $dirs
  if ($status -eq 0) { Write-Info "Build(s) completed successfully. Artifacts under */build/libs/" } else { Write-Err "One or more builds failed."; exit 1 }
} else {
  Write-Info "To attempt a local build, re-run this script with -RunBuild. Example:"
  Write-Info "  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_setup.ps1 -RunBuild"
  Write-Info "If you don't have a JDK, install one first using winget or choco (see messages above)."
}

