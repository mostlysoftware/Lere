<#
.SYNOPSIS
  Extracted JDK installer logic (user-local, no-admin Temurin/Adoptium installer).

.DESCRIPTION
  Provides Install-TemurinJdk which attempts to download and extract a JDK into
  a repository-local directory (./.dev/jdk). This is a thin extraction of the
  logic previously embedded in `scripts/dev_setup.ps1`.
#>

function Install-TemurinJdk {
  param(
    [string]$Version = '17',
    [string]$Root = (Resolve-Path -Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path),
    [switch]$ForceJdk,
    [switch]$SkipChecksum
  )

  $devJdkDir = Join-Path $Root '.dev\jdk'
  if (-not (Test-Path $devJdkDir)) { New-Item -ItemType Directory -Path $devJdkDir -Force | Out-Null }

  function Invoke-WithRetry {
    param(
      [scriptblock]$Action,
      [int]$Retries = 3,
      [int]$DelaySeconds = 2
    )
    for ($i = 1; $i -le $Retries; $i++) {
      try {
        return & $Action
      } catch {
        if ($i -lt $Retries) {
          Write-Warn "Attempt $i failed: $($_.Exception.Message). Retrying in $DelaySeconds seconds..."
          Start-Sleep -Seconds $DelaySeconds
          $DelaySeconds = [int]($DelaySeconds * 2)
          continue
        } else {
          throw
        }
      }
    }
  }

  if (-not $ForceJdk) {
    $existing = Get-ChildItem -Path $devJdkDir -Directory -ErrorAction SilentlyContinue | Where-Object {
      (Test-Path (Join-Path $_.FullName 'bin\javac.exe')) -or (Test-Path (Join-Path $_.FullName 'bin/javac'))
    } | Select-Object -First 1
    if ($null -ne $existing) {
      Write-Info "Found existing local JDK at $($existing.FullName); skipping download (use -ForceJdk to re-download)."
      $env:JAVA_HOME = $existing.FullName
      $env:Path = (Join-Path $existing.FullName 'bin') + [System.IO.Path]::PathSeparator + $env:Path
      return $true
    }
  }

  # Determine OS name and architecture
  $osCandidates = @()
  try {
    if ($env:OS -eq 'Windows_NT') { $osCandidates += 'windows' }
    if (Get-Variable -Name IsLinux -Scope Script -ErrorAction SilentlyContinue) { if ($IsLinux) { $osCandidates += 'linux' } }
    if (Get-Variable -Name IsMacOS -Scope Script -ErrorAction SilentlyContinue) { if ($IsMacOS) { $osCandidates += 'mac' } }
    try {
      if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { $osCandidates += 'windows' }
      if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) { $osCandidates += 'linux' }
      if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { $osCandidates += 'mac' }
    } catch { }
  } catch { }
  $osCandidates = $osCandidates | Select-Object -Unique
  if ($osCandidates.Count -eq 0) { $osCandidates = @('linux','mac','windows') }

  $archRaw = 'x64'
  try { $archRaw = ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToString() } catch { }
  switch ($archRaw.ToLower()) {
    'x64' { $arch = 'x64' }
    'arm64' { $arch = 'aarch64' }
    'arm' { $arch = 'aarch64' }
    'x86' { $arch = 'x86' }
    default { $arch = 'x64' }
  }

  $jvmImpl = 'hotspot'
  $imageType = 'jdk'

  $downloadOk = $false
  $tmpFile = $null
  $downloadUrl = $null

  $archVariants = @($arch, 'x86_64', 'amd64') | Select-Object -Unique
  $osVariants = @()
  foreach ($o in $osCandidates) {
    $osVariants += $o
    if ($o -eq 'windows') { $osVariants += 'win' }
    if ($o -eq 'mac') { $osVariants += 'macos' }
  }
  $osVariants = $osVariants | Select-Object -Unique

  foreach ($trialArch in $archVariants) {
    foreach ($trialOs in $osVariants) {
      $assetApi = "https://api.adoptium.net/v3/assets/latest/$Version/ga?architecture=$trialArch&image_type=$imageType&jvm_impl=$jvmImpl&os=$trialOs"
      Write-Info "Querying Adoptium assets: $assetApi"
      try {
        $meta = Invoke-RestMethod -Uri $assetApi -UseBasicParsing -ErrorAction Stop
        foreach ($entry in $meta) {
          if ($null -ne $entry.binaries) {
            foreach ($b in $entry.binaries) {
              if ($null -ne $b.package -and $b.package.link) {
                $downloadUrl = $b.package.link
                if ($null -ne $b.package.checksum) { $expectedChecksum = $b.package.checksum }
                $downloadOk = $true
                break
              }
            }
          }
          if ($downloadOk) { break }
        }
        if ($downloadOk) { break }
      } catch {
        Write-Warn "Asset query failed for ${trialOs}/${trialArch}: $($_.Exception.Message)"
        continue
      }
    }
    if ($downloadOk) { break }
  }

  if (-not $downloadOk) {
    foreach ($trialArch in $archVariants) {
      foreach ($trialOs in $osVariants) {
        $apiUrl = "https://api.adoptium.net/v3/binary/latest/$Version/ga/$trialOs/$trialArch/$imageType/$jvmImpl/$imageType"
        Write-Info "Checking availability (fallback): $apiUrl"
        try {
          Invoke-WebRequest -Uri $apiUrl -Method Head -UseBasicParsing -ErrorAction Stop | Out-Null
          $downloadUrl = $apiUrl
          $downloadOk = $true
          break
        } catch {
          continue
        }
      }
      if ($downloadOk) { break }
    }
  }

  if (-not $downloadOk) {
    Write-Err "Could not find a suitable Temurin binary for OS/arch (candidates: $($osCandidates -join ', '); arch=$arch)."
    return $false
  }

  $tmpFile = Join-Path $env:TEMP "temurin-jdk-$Version-$(Get-Random).bin"
  Write-Info "Preparing checksum lookup for Adoptium asset"
  $expectedChecksum = $null
  try {
    $assetApi = "https://api.adoptium.net/v3/assets/latest/$Version/ga?architecture=$arch&image_type=$imageType&jvm_impl=$jvmImpl&os=$trial"
    Write-Info "Fetching asset metadata: $assetApi"
    $meta = Invoke-RestMethod -Uri $assetApi -UseBasicParsing -ErrorAction Stop
    foreach ($entry in $meta) {
      if ($null -ne $entry.binaries) {
        foreach ($b in $entry.binaries) {
          if ($null -ne $b.package -and $b.package.checksum) { $expectedChecksum = $b.package.checksum; break }
        }
      }
      if ($expectedChecksum) { break }
    }
  } catch {
    Write-Warn "Could not fetch asset metadata for checksum: $($_.Exception.Message)"
  }

  Write-Info "Downloading JDK from $downloadUrl (this may be large)"
  try {
    Invoke-WithRetry -Action { Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile -UseBasicParsing -ErrorAction Stop } -Retries 3 -DelaySeconds 2 | Out-Null
  } catch {
    Write-Err "Failed to download JDK after retries: $($_.Exception.Message)"
    if ($tmpFile -and (Test-Path $tmpFile)) { Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue }
    return $false
  }

  $verificationResult = $null
  if (-not $SkipChecksum -and $expectedChecksum) {
    try {
      $verificationResult = Verify-FileChecksum -FilePath $tmpFile -ExpectedChecksum $expectedChecksum
      if (-not $verificationResult.Verified) {
        Write-Err "Downloaded JDK checksum mismatch. Expected $($verificationResult.Expected) but got $($verificationResult.Computed)."
        if ($tmpFile -and (Test-Path $tmpFile)) { Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue }
        try { $vpath = Join-Path $Root '.dev\jdk_verification.json'; $verificationResult | ConvertTo-Json | Out-File -FilePath $vpath -Encoding UTF8 -Force } catch { }
        return $false
      } else {
        Write-Info "Checksum verified (sha256)."
        try { $vpath = Join-Path $Root '.dev\jdk_verification.json'; $verificationResult | ConvertTo-Json | Out-File -FilePath $vpath -Encoding UTF8 -Force } catch { }
      }
    } catch {
      Write-Warn "Checksum verification failed: $($_.Exception.Message)"
    }
  }

  $fileType = 'unknown'
  try {
    $fs = [System.IO.File]::OpenRead($tmpFile)
    $buffer = New-Object byte[] 4
    $fs.Read($buffer,0,4) | Out-Null
    $fs.Close()
    if ($buffer[0] -eq 0x50 -and $buffer[1] -eq 0x4B) { $fileType = 'zip' }
    if ($buffer[0] -eq 0x1F -and $buffer[1] -eq 0x8B) { $fileType = 'tgz' }
  } catch { }

  Write-Info "Extracting JDK to $devJdkDir (detected type: $fileType)"
  try {
    if ($fileType -eq 'zip') {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpFile, $devJdkDir)
    } elseif ($fileType -eq 'tgz') {
      $tar = 'tar'
      try {
        & $tar -xzf $tmpFile -C $devJdkDir
      } catch {
        Write-Err "Failed to extract tarball with 'tar'. Ensure 'tar' is available on PATH."
        if ($tmpFile -and (Test-Path $tmpFile)) { Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue }
        return $false
      }
    } else {
      Write-Warn "Unknown archive format; attempting to extract as zip first."
      try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpFile, $devJdkDir)
      } catch {
        Write-Err "Extraction failed for unknown archive format: $($_.Exception.Message)"
        if ($tmpFile -and (Test-Path $tmpFile)) { Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue }
        return $false
      }
    }
  } catch {
    Write-Err "Extraction failed: $($_.Exception.Message)"
    return $false
  }

  $extracted = Get-ChildItem -Path $devJdkDir | Where-Object { $_.PSIsContainer } | Where-Object {
    (Test-Path (Join-Path $_.FullName 'bin\javac.exe')) -or (Test-Path (Join-Path $_.FullName 'bin/javac'))
  } | Select-Object -First 1

  if ($null -eq $extracted) {
    Write-Err "Could not find a valid JDK layout inside the extracted archive."
    return $false
  }

  $jdkHome = $extracted.FullName
  Write-Info "Using extracted JDK at: $jdkHome"
  $env:JAVA_HOME = $jdkHome
  if ($IsWindows -or ($env:OS -eq 'Windows_NT')) { $binPath = Join-Path $jdkHome 'bin' } else { $binPath = Join-Path $jdkHome 'bin' }
  $env:Path = $binPath + [System.IO.Path]::PathSeparator + $env:Path

  $javacCheck = Get-Command javac -ErrorAction SilentlyContinue
  if ($null -ne $javacCheck) {
    Write-Info "javac found: $($javacCheck.Path)"
    try { Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue } catch { }
    return $true
  } else {
    Write-Err "javac still not available after extraction."
    return $false
  }
}
