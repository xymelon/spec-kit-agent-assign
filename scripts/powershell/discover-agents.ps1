<#
.SYNOPSIS
    Deterministic Claude Code agent discovery for spec-kit-agent-assign.

.DESCRIPTION
    Scans Claude Code agent definition directories in priority order and
    emits one JSON object per discovered agent. Agents discovered at a higher
    priority source block the same-named agent from lower priority sources.

    Priority (highest to lowest):
      project  → <RepoRoot>/.claude/agents/*.md
      user     → ~/.claude/agents/*.md
      custom   → directories listed in additional_agent_sources of agent-assign.yml

.PARAMETER RepoRoot
    Path to the repository root. Defaults to current directory.

.PARAMETER Config
    Path to .claude/agent-assign.yml config file. Defaults to <RepoRoot>\.claude\agent-assign.yml if omitted.
    If omitted or if the file does not exist, only the standard two paths are scanned.

.OUTPUTS
    JSON Lines — one compact JSON object per discovered agent, e.g.:
    {"name":"backend-dev","source":"project","description":"...","path":"C:\abs\path\backend-dev.md"}

.EXAMPLE
    .\discover-agents.ps1

.EXAMPLE
    .\discover-agents.ps1 -RepoRoot C:\my-project -Config C:\my-project\.claude\agent-assign.yml
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$Config = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Config -eq "") {
    $Config = Join-Path $RepoRoot ".claude\agent-assign.yml"
}

# ---------------------------------------------------------------------------
# Deduplication registry
# ---------------------------------------------------------------------------
$SeenAgents = @{}

# ---------------------------------------------------------------------------
# Expand ~ to $HOME in a path string
# ---------------------------------------------------------------------------
function Expand-HomePath {
    param([string]$Path)
    if ($Path.StartsWith("~")) {
        return $Path -replace "^~", $HOME
    }
    return $Path
}

# ---------------------------------------------------------------------------
# Resolve a path: expand ~ then resolve relative paths against RepoRoot
# ---------------------------------------------------------------------------
function Resolve-AgentPath {
    param([string]$Path)
    $Path = Expand-HomePath $Path
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path $RepoRoot $Path
    }
    return $Path
}

# ---------------------------------------------------------------------------
# Extract name and description from a markdown file's YAML frontmatter.
# Returns a hashtable with Name and Description keys.
# ---------------------------------------------------------------------------
function Get-FrontmatterFields {
    param([string]$FilePath)

    $name        = ""
    $description = ""
    $inFrontmatter  = $false
    $foundStart  = $false

    foreach ($line in [System.IO.File]::ReadLines($FilePath)) {
        if ($line.Trim() -eq "---") {
            if (-not $foundStart) {
                $foundStart    = $true
                $inFrontmatter = $true
                continue
            } else {
                break
            }
        }

        if (-not $inFrontmatter) { continue }

        if ($line -match '^name:\s*(.+)$') {
            $name = $Matches[1].Trim().Trim('"').Trim("'")
        }
        if ($line -match '^description:\s*(.+)$') {
            $description = $Matches[1].Trim().Trim('"').Trim("'")
        }
    }

    return @{ Name = $name; Description = $description }
}

# ---------------------------------------------------------------------------
# Emit one agent as a JSON Line using PowerShell's built-in serializer.
# ---------------------------------------------------------------------------
function Write-AgentJson {
    param(
        [string]$Name,
        [string]$Source,
        [string]$Description,
        [string]$Path
    )
    $obj = [ordered]@{
        name        = $Name
        source      = $Source
        description = $Description
        path        = $Path
    }
    Write-Output ($obj | ConvertTo-Json -Compress -Depth 1)
}

# ---------------------------------------------------------------------------
# Scan a directory for *.md agent files and emit each as a JSON Line.
# ---------------------------------------------------------------------------
function Invoke-DiscoverFromDirectory {
    param(
        [string]$Dir,
        [string]$SourceLabel
    )

    $Dir = Resolve-AgentPath $Dir

    if (-not (Test-Path $Dir -PathType Container)) { return }

    Get-ChildItem -Path $Dir -Filter "*.md" -File | ForEach-Object {
        $absPath = $_.FullName
        $fields  = Get-FrontmatterFields -FilePath $absPath
        $name    = $fields.Name
        $desc    = $fields.Description

        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($absPath)
        }

        if ($SeenAgents.ContainsKey($name)) { return }
        $SeenAgents[$name] = $true

        Write-AgentJson -Name $name -Source $SourceLabel -Description $desc -Path $absPath
    }
}

# ---------------------------------------------------------------------------
# Parse additional_agent_sources from agent-assign.yml.
# Returns a list of hashtables with Path and Label keys.
# ---------------------------------------------------------------------------
function Get-ConfigSources {
    param([string]$ConfigPath)

    $ConfigPath = Resolve-AgentPath $ConfigPath

    if (-not (Test-Path $ConfigPath -PathType Leaf)) { return @() }

    $sources      = [System.Collections.Generic.List[hashtable]]::new()
    $inSources    = $false
    $currentPath  = ""
    $currentLabel = ""

    foreach ($line in [System.IO.File]::ReadLines($ConfigPath)) {
        $stripped = $line.TrimStart()

        if ($stripped -eq "additional_agent_sources:") {
            $inSources = $true
            continue
        }

        # Top-level non-indented non-empty key ends the section
        if ($inSources -and $line.Length -gt 0 -and
            $line[0] -ne ' ' -and $line[0] -ne "`t" -and
            -not $stripped.StartsWith("-")) {
            $inSources = $false
        }

        if (-not $inSources) { continue }

        if ($stripped -match '^-\s+path:\s*(.+)$') {
            if ($currentPath -ne "") {
                $sources.Add(@{ Path = $currentPath; Label = $currentLabel })
                $currentLabel = ""
            }
            $currentPath = $Matches[1].Trim().Trim('"').Trim("'")
        } elseif ($stripped -match '^path:\s*(.+)$') {
            $currentPath = $Matches[1].Trim().Trim('"').Trim("'")
        } elseif ($stripped -match '^label:\s*(.+)$') {
            $currentLabel = $Matches[1].Trim().Trim('"').Trim("'")
        }
    }

    if ($currentPath -ne "") {
        $sources.Add(@{ Path = $currentPath; Label = $currentLabel })
    }

    return $sources
}

# ---------------------------------------------------------------------------
# Main discovery sequence
# ---------------------------------------------------------------------------

# 1. Project-level (highest priority)
Invoke-DiscoverFromDirectory -Dir (Join-Path $RepoRoot ".claude\agents") -SourceLabel "project"

# 2. User-level
Invoke-DiscoverFromDirectory -Dir (Join-Path $HOME ".claude\agents") -SourceLabel "user"

# 3. Config-based additional sources
if ($Config -ne "") {
    $extraSources = Get-ConfigSources -ConfigPath $Config
    foreach ($src in $extraSources) {
        $label = if ($src.Label -ne "") { $src.Label } else { "custom" }
        Invoke-DiscoverFromDirectory -Dir $src.Path -SourceLabel $label
    }
}
