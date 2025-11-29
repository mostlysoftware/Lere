$jdkHome='C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot'
$env:JAVA_HOME=$jdkHome
$env:Path = (Join-Path $jdkHome 'bin') + [System.IO.Path]::PathSeparator + $env:Path
Write-Output "JAVA_HOME set to: $env:JAVA_HOME"
Get-Command javac -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ("javac found: " + $_.Path) }
& 'C:\Users\Eris\Dropbox\Dev\Lere\scripts\dev_setup.ps1' -AutoInstallJdk -JdkVersion 17
