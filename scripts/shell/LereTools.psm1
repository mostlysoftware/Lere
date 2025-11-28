#requires -Version 3.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root based on module location: scripts/shell/ -> repo root is two levels up
$script:RepoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
$script:ScriptsDir = (Join-Path $script:RepoRoot 'scripts')
$script:ContextDir = (Join-Path $script:RepoRoot 'chat_context')

function Invoke-LereHealthCheck {
  [CmdletBinding()]
  param(
    [ValidateSet('all','project','scripts','plugins','context')]
    [string]$Scope = 'all',

    [ValidateSet('console','json','markdown')]
    [string]$Report = 'console',

    [switch]$Fix,
    [switch]$Verbose
  )
  $hc = Join-Path $script:ScriptsDir 'health_check.ps1'
  if (-not (Test-Path $hc)) { throw "health_check.ps1 not found at $hc" }
  & $hc -Scope $Scope -Report $Report -Fix:$Fix -Verbose:$Verbose
}

function Invoke-LereOffload {
  [CmdletBinding()]
  param(
    [string[]]$Files = @('ATTACHMENTS.md','knowledge-compartmentalization.md'),
    [switch]$Push
  )
  $off = Join-Path $script:ScriptsDir 'offload_context_files.ps1'
  if (-not (Test-Path $off)) { throw "offload_context_files.ps1 not found at $off" }
  & $off -Files $Files -Push:$Push
}

function Invoke-LerePurgeTopLevelSummaries {
  [CmdletBinding()]
  param([switch]$NoGit)
  $purge = Join-Path $script:ScriptsDir 'remove_top_level_summaries.ps1'
  if (-not (Test-Path $purge)) { throw "remove_top_level_summaries.ps1 not found at $purge" }
  & $purge
}

function Invoke-LereGenerateSummaries {
  [CmdletBinding()]
  param(
    [int]$PreviewLines = 40,
    [int]$MaxLines = 800,
    [switch]$Force
  )
  $gen = Join-Path $script:ScriptsDir 'generate_context_summaries.ps1'
  if (-not (Test-Path $gen)) { throw "generate_context_summaries.ps1 not found at $gen" }
  & $gen -Root $script:ContextDir -PreviewLines $PreviewLines -MaxLines $MaxLines -Force:$Force
}

# Aliases
Set-Alias -Name hc -Value Invoke-LereHealthCheck -Force
Set-Alias -Name hcf -Value Invoke-LereHealthCheck -Force
Set-Alias -Name offload -Value Invoke-LereOffload -Force
Set-Alias -Name purgesummaries -Value Invoke-LerePurgeTopLevelSummaries -Force
Set-Alias -Name ctxsum -Value Invoke-LereGenerateSummaries -Force

# Argument completers for nicer UX
Register-ArgumentCompleter -CommandName Invoke-LereHealthCheck -ParameterName Scope -ScriptBlock {
  param($commandName,$parameterName,$wordToComplete)
  'all','project','scripts','plugins','context' | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}
Register-ArgumentCompleter -CommandName Invoke-LereHealthCheck -ParameterName Report -ScriptBlock {
  param($commandName,$parameterName,$wordToComplete)
  'console','json','markdown' | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}

Export-ModuleMember -Function Invoke-LereHealthCheck, Invoke-LereOffload, Invoke-LerePurgeTopLevelSummaries, Invoke-LereGenerateSummaries -Alias hc,hcf,offload,purgesummaries,ctxsum
