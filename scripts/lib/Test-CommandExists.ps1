<#
.SYNOPSIS
Utility to check whether a given command is available on PATH.

.DESCRIPTION
Provides a single function `Test-CommandExists` that returns $true when
the specified command is resolvable via Get-Command, otherwise $false.

.PARAMETER Cmd
Command name to check (string)

.EXAMPLE
  Test-CommandExists -Cmd 'gradle'
#>

param()

function Test-CommandExists {
    param([string]$Cmd)
    return (Get-Command $Cmd -ErrorAction SilentlyContinue) -ne $null
}

# Export friendly name when dot-sourced
Set-Item -Path function:Test-CommandExists -Value (Get-Item function:Test-CommandExists).ScriptBlock -Force | Out-Null
