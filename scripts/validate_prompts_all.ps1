param(
    [string]$MdFile = 'chat_context/pending_prompts.md',
    [string]$JsonFile = 'chat_context/pending_prompts.json'
)
. $PSScriptRoot\\lib\\logging.ps1

Write-Info "Running unified prompt validations"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$mdScript = Join-Path $scriptDir 'validate_prompts.ps1'
$jsonScript = Join-Path $scriptDir 'validate_prompts_json.ps1'

if (-not (Test-Path $mdScript)) { Write-Error "Missing md validator: $mdScript"; exit 2 }
if (-not (Test-Path $jsonScript)) { Write-Error "Missing json validator: $jsonScript"; exit 2 }

Write-Info "1) Running MD validator..."
& $mdScript -File $MdFile
$mdExit = $LASTEXITCODE
Write-Info "MD validator exit code: $mdExit"

Write-Info "2) Running JSON validator..."
& $jsonScript -File $JsonFile
$jsonExit = $LASTEXITCODE
Write-Info "JSON validator exit code: $jsonExit"

if ($mdExit -ne 0 -or $jsonExit -ne 0) {
    Write-Error "One or more validations failed (md:$mdExit, json:$jsonExit)"
    exit 10
}

Write-Info "All validations passed." -ForegroundColor Green
exit 0

