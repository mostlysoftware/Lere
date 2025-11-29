try { Start-RunLog -Root (Resolve-Path -Path ""$PSScriptRoot\.."" | Select-Object -ExpandProperty Path) -ScriptName "schedule_health_check" -Note "auto-applied" } catch { }
<#
.SYNOPSIS
  Set up Windows Task Scheduler to run health checks at regular intervals.

.DESCRIPTION
  Creates a scheduled task that runs the health check script weekly.
  Results are logged to scripts/audit-data/logs/health-check-*.log

.PARAMETER Action
  'install' - Create the scheduled task
  'uninstall' - Remove the scheduled task
  'run' - Run the task immediately
  'status' - Show task status

.PARAMETER Frequency
  'daily', 'weekly', 'monthly'
  Default: 'weekly'

.PARAMETER Time
  Time to run (24h format, e.g., '06:00')
  Default: '06:00'

.EXAMPLE
  # Install weekly health check at 6am on Sundays
  .\schedule_health_check.ps1 -Action install

  # Install daily at 7am
  .\schedule_health_check.ps1 -Action install -Frequency daily -Time '07:00'

  # Run immediately
  .\schedule_health_check.ps1 -Action run

  # Check status
  .\schedule_health_check.ps1 -Action status

  # Uninstall
  .\schedule_health_check.ps1 -Action uninstall
#>

param(
  [ValidateSet('install', 'uninstall', 'run', 'status')]
  [string]$Action = 'status',
  
  [ValidateSet('daily', 'weekly', 'monthly')]
  [string]$Frequency = 'weekly',
  
  [string]$Time = '06:00'
)

$taskName = "LereHealthCheck"
$root = (Resolve-Path -Path "$PSScriptRoot\..").Path
$scriptPath = Join-Path $PSScriptRoot 'health_check.ps1'
$logDir = Join-Path $root 'scripts\audit-data\logs'

function Install-HealthCheckTask {
  # Ensure log directory exists
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }
  
  # Build the PowerShell command - uses single quotes to defer variable expansion
  $wrapperScript = Join-Path $PSScriptRoot 'run_health_check_logged.ps1'
  
  # Create a simple wrapper script that handles logging
  $wrapperContent = @'
# Auto-generated wrapper for scheduled health check
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path (Split-Path -Parent $scriptDir) 'scripts\audit-data\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logFile = Join-Path $logDir "health-check-$timestamp.log"
& (Join-Path $scriptDir 'health_check.ps1') -Scope all -Report console 2>&1 | Tee-Object -FilePath $logFile
'@
  $wrapperContent | Set-Content -Path $wrapperScript -Encoding UTF8

  # Create trigger based on frequency
  $trigger = switch ($Frequency) {
    'daily' {
      New-ScheduledTaskTrigger -Daily -At $Time
    }
    'weekly' {
      New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $Time
    }
    'monthly' {
      New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Sunday -At $Time
    }
  }
  
  # Create the action
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapperScript`"" `
    -WorkingDirectory $root

  # Task settings
  $settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false

  # Check if task already exists
  $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Info "Updating existing task '$taskName'..." -ForegroundColor Yellow
    Set-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings | Out-Null
  } else {
    Write-Info "Creating new task '$taskName'..." -ForegroundColor Cyan
    Register-ScheduledTask -TaskName $taskName `
      -Trigger $trigger `
      -Action $action `
      -Settings $settings `
      -Description "Lere Project Health Check - runs $Frequency at $Time" | Out-Null
  }
  
  Write-Info "Health check scheduled: $Frequency at $Time" -ForegroundColor Green
  Write-Info "  Logs will be saved to: $logDir" -ForegroundColor Gray
}

function Uninstall-HealthCheckTask {
  $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Info "Task '$taskName' removed" -ForegroundColor Green
  } else {
    Write-Info "Task '$taskName' not found" -ForegroundColor Yellow
  }
}

function Get-HealthCheckStatus {
  $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if (-not $task) {
    Write-Info "Task '$taskName' is not installed" -ForegroundColor Yellow
    Write-Info ""
    Write-Info "To install, run:" -ForegroundColor Gray
    Write-Info "  .\schedule_health_check.ps1 -Action install" -ForegroundColor White
    return
  }
  
  $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
  
  Write-Info "=== Health Check Task Status ===" -ForegroundColor Cyan
  Write-Info ""
  Write-Info "Task Name:    $taskName" -ForegroundColor White
  
  $stateColor = if ($task.State -eq 'Ready') { 'Green' } else { 'Yellow' }
  Write-Info "State:        $($task.State)" -ForegroundColor $stateColor
  
  Write-Info "Last Run:     $($taskInfo.LastRunTime)" -ForegroundColor Gray
  
  $resultColor = if ($taskInfo.LastTaskResult -eq 0) { 'Green' } else { 'Red' }
  Write-Info "Last Result:  $($taskInfo.LastTaskResult)" -ForegroundColor $resultColor
  
  Write-Info "Next Run:     $($taskInfo.NextRunTime)" -ForegroundColor Gray
  Write-Info ""
  
  # Show recent logs
  if (Test-Path $logDir) {
    $logs = Get-ChildItem -Path $logDir -Filter 'health-check-*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 5
    if ($logs.Count -gt 0) {
      Write-Info "Recent logs:" -ForegroundColor White
      foreach ($log in $logs) {
        Write-Info "  $($log.Name) ($([math]::Round($log.Length / 1024, 1))KB)" -ForegroundColor Gray
      }
    }
  }
}

function Invoke-HealthCheckNow {
  Write-Info "Running health check now..." -ForegroundColor Cyan
  
  # Ensure log directory exists
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }
  
  $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $logFile = Join-Path $logDir "health-check-$timestamp.log"
  
  # Run health check
  & $scriptPath -Scope all -Report console 2>&1 | Tee-Object -FilePath $logFile
  
  Write-Info ""
  Write-Info "Log saved to: $logFile" -ForegroundColor Gray
}

# Main
switch ($Action) {
  'install' { Install-HealthCheckTask }
  'uninstall' { Uninstall-HealthCheckTask }
  'run' { Invoke-HealthCheckNow }
  'status' { Get-HealthCheckStatus }
}

