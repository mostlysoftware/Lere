<#
Simple helper to check for Java and Gradle in PATH and provide guidance to the developer.
Usage: PowerShell: .\scripts\check_build_env.ps1
#>

function Test-CommandExists {
    param([string]$Cmd)
    return (Get-Command $Cmd -ErrorAction SilentlyContinue) -ne $null
}

Write-Host "Checking build environment..." -ForegroundColor Cyan

if (-not (Test-CommandExists -Cmd 'java')) {
    Write-Host "Java runtime not found in PATH." -ForegroundColor Yellow
    Write-Host "Please install a JDK 17 and ensure 'java' is on PATH. Examples:"
    Write-Host "  - Install Temurin 17 via Chocolatey:  choco install temurin17jdk -y" -ForegroundColor DarkGray
    Write-Host "  - Or download from https://adoptium.net/ and set JAVA_HOME and PATH accordingly." -ForegroundColor DarkGray
} else {
    Write-Host "Java detected:" -ForegroundColor Green
    & java -version 2>&1 | ForEach-Object { Write-Host $_ }
}

if (-not (Test-CommandExists -Cmd 'gradle')) {
    Write-Host "Gradle not found in PATH." -ForegroundColor Yellow
    Write-Host "Options:"
    Write-Host "  - Install Gradle via Chocolatey: choco install gradle -y" -ForegroundColor DarkGray
    Write-Host "  - Or install Gradle locally and add to PATH, or create a Gradle wrapper by running 'gradle wrapper --gradle-version <version>' on a machine with Gradle installed." -ForegroundColor DarkGray
    Write-Host "Tip: To make builds reproducible, run 'gradle wrapper --gradle-version 8.4.1' at the repository root and commit the wrapper files." -ForegroundColor DarkGray
} else {
    Write-Host "Gradle detected:" -ForegroundColor Green
    & gradle -v 2>&1 | ForEach-Object { Write-Host $_ }
}

Write-Host ""; Write-Host "To build locally once Java+Gradle are available:" -ForegroundColor Cyan
Write-Host "  gradle -p plugins/lere_core build" -ForegroundColor DarkGray
Write-Host "  gradle -p plugins/lere_multiplayer build" -ForegroundColor DarkGray
Write-Host "Or, after adding the Gradle wrapper (recommended):" -ForegroundColor Cyan
Write-Host "  ./gradlew -p plugins/lere_core build   # on Unix/macOS" -ForegroundColor DarkGray
Write-Host "  .\gradlew.bat -p plugins\lere_core build # on Windows" -ForegroundColor DarkGray

Write-Host "I also added a CI workflow (.github/workflows/build-plugins.yml) that will attempt these builds on GitHub Actions (Java 17 + Gradle)." -ForegroundColor Cyan

exit 0
