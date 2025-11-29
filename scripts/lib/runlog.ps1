<#
.SYNOPSIS
  Structured run-log helpers that build on existing logging.ps1 helpers.

.DESCRIPTION
  This file provides a small facade for structured logging and run-log JSON
  entries. It dot-sources the existing logging helpers (logging.ps1) so callers
  may continue to use older functions while new code can call the structured API.

  Usage (from scripts):
    . "$PSScriptRoot\runlog.ps1"
    Start-RunLogEx -Root $root -ScriptName 'health_check' -Note 'Health checks'
    Write-StructuredLog -Level Info -Message 'Started checks' -Metadata @{step='init'}
#>

try { . "$PSScriptRoot\logging.ps1" } catch { }

function Start-RunLogEx {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$ScriptName,
        [string]$Note
    )
    # Delegate to the existing Start-RunLog to preserve behavior/backwards compat
    try { Start-RunLog -Root $Root -ScriptName $ScriptName -Note $Note } catch { }
}

function Write-StructuredLog {
    param(
        [ValidateSet('Info','Warn','Error')][string]$Level = 'Info',
        [Parameter(Mandatory=$true)][string]$Message,
        [hashtable]$Metadata
    )
    # Console output using existing helpers
    switch ($Level) {
        'Info' { try { Write-Info $Message } catch { Write-Host $Message } }
        'Warn' { try { Write-Warn $Message } catch { Write-Host $Message } }
        'Error' { try { Write-Err $Message } catch { Write-Host $Message } }
    }

    # Append a structured JSON entry to the run log if available
    try {
        if ($null -ne $global:FirstTimeLogPath -and (Test-Path $global:FirstTimeLogPath)) {
            $entry = [ordered]@{
                timestamp = (Get-Date).ToString('o')
                level = $Level
                message = $Message
                metadata = $Metadata
            }
            $json = ($entry | ConvertTo-Json -Depth 5)
            Add-Content -Path $global:FirstTimeLogPath -Value $json
        }
    } catch { }
}

function Save-RunLogToSummariesEx {
    param(
        [Parameter(Mandatory=$true)][string]$Root
    )
    try { Save-RunLogToSummaries -Root $Root } catch { }
}

# end of runlog.ps1
