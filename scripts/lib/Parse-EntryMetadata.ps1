<#
.SYNOPSIS
  Shared metadata parsing utilities for session/reasoning entries.

.DESCRIPTION
  Provides unified parsing for HTML comment metadata blocks used in:
  - session-context.md (sessions)
  - reasoning-context.md (threads)

  Metadata block format:
    <!-- metadata
    Priority: high|low
    Status: open|closed|resolved
    Last-updated: YYYY-MM-DD HH:MM
    Archived: true|false
    -->

.EXAMPLE
  . .\lib\Parse-EntryMetadata.ps1
  $meta = Parse-EntryMetadata -Text $blockText
  if ($meta.Status -eq 'resolved') { ... }
#>

function Parse-EntryMetadata {
  <#
  .SYNOPSIS
    Extract metadata from an HTML comment block within entry text.
  .PARAMETER Text
    The full text of a session or reasoning entry.
  .OUTPUTS
    PSCustomObject with Priority, Status, LastUpdated, Archived properties.
  #>
  param(
    [Parameter(Mandatory=$true)]
    [string]$Text
  )

  $result = [PSCustomObject]@{
    Priority    = 'low'
    Status      = 'open'
    LastUpdated = $null
    Archived    = $false
    HasMetadata = $false
  }

  # Match the metadata block: <!-- metadata ... -->
  if ($Text -match '(?s)<!--\s*metadata\s*\n(.*?)\n?\s*-->') {
    $result.HasMetadata = $true
    $metaBlock = $Matches[1]

    # Parse Priority
    if ($metaBlock -match 'Priority:\s*(high|low)') {
      $result.Priority = $Matches[1].ToLower()
    }

    # Parse Status
    if ($metaBlock -match 'Status:\s*(open|closed|resolved)') {
      $result.Status = $Matches[1].ToLower()
    }

    # Parse Last-updated
    if ($metaBlock -match 'Last-updated:\s*(\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2})?)') {
      $dateStr = $Matches[1]
      try {
        if ($dateStr -match '\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}') {
          $result.LastUpdated = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd HH:mm', $null)
        } else {
          $result.LastUpdated = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd', $null)
        }
      } catch { }
    }

    # Parse Archived
    if ($metaBlock -match 'Archived:\s*(true|false)') {
      $result.Archived = ($Matches[1].ToLower() -eq 'true')
    }
  }

  return $result
}

function Format-EntryMetadata {
  <#
  .SYNOPSIS
    Generate a metadata block string for embedding in an entry.
  .PARAMETER Priority
    Priority level: 'high' or 'low'. Default: 'low'.
  .PARAMETER Status
    Status value: 'open', 'closed', or 'resolved'. Default: 'open'.
  .PARAMETER LastUpdated
    DateTime for last update. Default: current time.
  .PARAMETER Archived
    Whether entry is archived. Default: $false.
  .OUTPUTS
    String containing the formatted metadata block.
  #>
  param(
    [string]$Priority = 'low',
    [string]$Status = 'open',
    [datetime]$LastUpdated = (Get-Date),
    [bool]$Archived = $false
  )

  $lines = @(
    '<!-- metadata',
    "Priority: $Priority",
    "Status: $Status",
    "Last-updated: $($LastUpdated.ToString('yyyy-MM-dd HH:mm'))",
    "Archived: $($Archived.ToString().ToLower())",
    '-->'
  )

  return ($lines -join "`n")
}

function Test-EntryEligibleForArchive {
  <#
  .SYNOPSIS
    Determine if an entry should be archived based on metadata.
  .PARAMETER Metadata
    PSCustomObject from Parse-EntryMetadata.
  .PARAMETER MaxAgeDays
    Archive entries older than this many days. Default: 30.
  .PARAMETER Now
    Reference datetime for age calculation. Default: current time.
  .OUTPUTS
    Boolean indicating archive eligibility.
  #>
  param(
    [Parameter(Mandatory=$true)]
    [PSCustomObject]$Metadata,
    [int]$MaxAgeDays = 30,
    [datetime]$Now = (Get-Date)
  )

  # Already archived entries are not eligible for re-archiving
  if ($Metadata.Archived) { return $false }

  # Resolved or closed entries are eligible
  if ($Metadata.Status -in @('resolved', 'closed')) { return $true }

  # Old entries are eligible
  if ($Metadata.LastUpdated -and $Metadata.LastUpdated -lt $Now.AddDays(-$MaxAgeDays)) {
    return $true
  }

  return $false
}

# Legacy fallback: infer metadata from old-style entries (for migration)
function Infer-LegacyMetadata {
  <#
  .SYNOPSIS
    Infer metadata from old-style session/reasoning entries.
  .PARAMETER Text
    Entry text in legacy format.
  .PARAMETER EntryType
    Either 'session' or 'reasoning'.
  .OUTPUTS
    PSCustomObject with inferred Priority, Status, LastUpdated.
  #>
  param(
    [Parameter(Mandatory=$true)]
    [string]$Text,
    [ValidateSet('session', 'reasoning')]
    [string]$EntryType = 'session'
  )

  $result = [PSCustomObject]@{
    Priority    = 'low'
    Status      = 'open'
    LastUpdated = $null
    Archived    = $false
    HasMetadata = $false
  }

  if ($EntryType -eq 'session') {
    # Infer priority from content
    if ($Text -match 'Priority:\s*(high|low)') {
      $result.Priority = $Matches[1].ToLower()
    } elseif ($Text -match 'Decisions made|Changelog entries|Summary:') {
      $result.Priority = 'high'
    }

    # Infer status from session type
    if ($Text -match 'Session Close|Session close') {
      $result.Status = 'closed'
    }

    # Extract date from session marker
    if ($Text -match '\(Session\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\)') {
      try {
        $result.LastUpdated = [datetime]::ParseExact("$($Matches[1]) $($Matches[2])", 'yyyy-MM-dd HH:mm', $null)
      } catch { }
    }
  } elseif ($EntryType -eq 'reasoning') {
    # Infer from Last updated field
    if ($Text -match '\*\*Last updated:\*\*\s*(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}))?') {
      try {
        $dateStr = $Matches[1]
        if ($Matches[2]) { $dateStr += " $($Matches[2])" }
        if ($dateStr -match '\d{2}:\d{2}') {
          $result.LastUpdated = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd HH:mm', $null)
        } else {
          $result.LastUpdated = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd', $null)
        }
      } catch { }
    }

    # Infer status from Checkpoint section
    if ($Text -match 'Checkpoint.*?\n\s*-\s*\S') {
      $result.Status = 'resolved'
    }
  }

  return $result
}

# Only export when loaded as a module (not dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
  Export-ModuleMember -Function Parse-EntryMetadata, Format-EntryMetadata, Test-EntryEligibleForArchive, Infer-LegacyMetadata
}
