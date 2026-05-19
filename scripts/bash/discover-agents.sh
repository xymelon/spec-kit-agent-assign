#!/usr/bin/env bash
# discover-agents.sh — Deterministic Claude Code agent discovery for spec-kit-agent-assign
#
# Usage:
#   discover-agents.sh [--repo-root <path>] [--config <path>]
#
# Flags:
#   --repo-root <path>   Repository root to scan (default: current directory)
#   --config <path>      Path to .claude/agent-assign.yml for extra sources (optional; default: <repo-root>/.claude/agent-assign.yml)
#
# Output:
#   JSON Lines — one compact JSON object per discovered agent, e.g.:
#   {"name":"backend-dev","source":"project","description":"...","path":"/abs/path/backend-dev.md"}
#
# Priority (highest to lowest, duplicates skipped):
#   project  → <repo-root>/.claude/agents/*.md
#   user     → ~/.claude/agents/*.md
#   custom   → directories listed in additional_agent_sources of agent-assign.yml
#
# Requirements:
#   - bash 3.2+ (macOS compatible)
#   - python3 (for correct JSON escaping)
#   - awk (standard POSIX utility)

set -euo pipefail

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required for JSON output but was not found on PATH." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
REPO_ROOT=""
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="${2:?--repo-root requires a value}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:?--config requires a value}"
      shift 2
      ;;
    --help|-h)
      grep '^#' "$0" | head -30 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option '$1'. Use --help for usage." >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
REPO_ROOT="${REPO_ROOT/#\~/$HOME}"
CONFIG_FILE="${CONFIG_FILE:-"$REPO_ROOT/.claude/agent-assign.yml"}"

# ---------------------------------------------------------------------------
# Extract name and description from a markdown file's YAML frontmatter.
# Prints "name|description" to stdout.
# ---------------------------------------------------------------------------
extract_frontmatter() {
  local file="$1"
  awk '
    BEGIN { in_fm=0; found_start=0; name=""; desc="" }
    /^---[[:space:]]*$/ {
      if (!found_start) { found_start=1; in_fm=1; next }
      else { in_fm=0; exit }
    }
    in_fm && /^name:[[:space:]]*/ {
      val = $0
      sub(/^name:[[:space:]]*/, "", val)
      gsub(/^["'"'"']|["'"'"']$/, "", val)
      name = val
    }
    in_fm && /^description:[[:space:]]*/ {
      val = $0
      sub(/^description:[[:space:]]*/, "", val)
      gsub(/^["'"'"']|["'"'"']$/, "", val)
      desc = val
    }
    END { printf "%s|%s\n", name, desc }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Deduplication registry — bash 3.2 compatible (no associative arrays).
# SEEN is a pipe-delimited string of agent names already recorded.
# ---------------------------------------------------------------------------
SEEN="|"
RECORDS=()

# ---------------------------------------------------------------------------
# Scan a directory for *.md agent files and append to RECORDS.
# ---------------------------------------------------------------------------
discover_from_dir() {
  local dir="$1"
  local source_label="$2"

  dir="${dir/#\~/$HOME}"

  # Resolve relative paths against REPO_ROOT
  if [[ "$dir" != /* ]]; then
    dir="$REPO_ROOT/$dir"
  fi

  [[ -d "$dir" ]] || return 0

  local file abs_path fields name desc stem
  for file in "$dir"/*.md; do
    [[ -f "$file" ]] || continue

    abs_path="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"

    fields="$(extract_frontmatter "$abs_path")"
    name="${fields%%|*}"
    desc="${fields#*|}"

    stem="$(basename "$abs_path" .md)"
    [[ -z "$name" ]] && name="$stem"

    # Skip if already recorded at higher priority
    [[ "$SEEN" == *"|${name}|"* ]] && continue

    SEEN="${SEEN}${name}|"
    RECORDS+=("${name}:::${source_label}:::${desc}:::${abs_path}")
  done
}

# ---------------------------------------------------------------------------
# Parse additional_agent_sources entries from the config YAML file.
# Prints "label|path" lines to stdout (label may be empty → caller defaults to "custom").
# ---------------------------------------------------------------------------
parse_config_sources() {
  local config="$1"

  [[ -f "$config" ]] || return 0

  local in_sources=0
  local current_path="" current_label=""

  while IFS= read -r line; do
    local stripped
    stripped="${line#"${line%%[! 	]*}"}"   # ltrim spaces and tabs

    if [[ "$stripped" == "additional_agent_sources:" ]]; then
      in_sources=1
      continue
    fi

    # A top-level (non-indented) non-empty key ends the section
    if [[ $in_sources -eq 1 && -n "$stripped" && "$line" == "$stripped" && "$stripped" != "-"* ]]; then
      in_sources=0
    fi

    [[ $in_sources -eq 0 ]] && continue

    # New list item starting with "- path:"
    if [[ "$stripped" == "- path:"* ]]; then
      if [[ -n "$current_path" ]]; then
        printf '%s|%s\n' "$current_label" "$current_path"
        current_path="" current_label=""
      fi
      current_path="${stripped#- path:}"
      current_path="${current_path#"${current_path%%[! ]*}"}"   # ltrim
      current_path="${current_path%"${current_path##*[! ]}"}"   # rtrim
      current_path="${current_path#\"}" current_path="${current_path%\"}"
      current_path="${current_path#\'}" current_path="${current_path%\'}"

    elif [[ "$stripped" == "- label:"* ]]; then
      # Compact form "- label: foo" (unusual but handle gracefully)
      current_label="${stripped#- label:}"
      current_label="${current_label#"${current_label%%[! ]*}"}"
      current_label="${current_label%"${current_label##*[! ]}"}"
      current_label="${current_label#\"}" current_label="${current_label%\"}"
      current_label="${current_label#\'}" current_label="${current_label%\'}"

    elif [[ "$stripped" == "path:"* ]]; then
      current_path="${stripped#path:}"
      current_path="${current_path#"${current_path%%[! ]*}"}"
      current_path="${current_path%"${current_path##*[! ]}"}"
      current_path="${current_path#\"}" current_path="${current_path%\"}"
      current_path="${current_path#\'}" current_path="${current_path%\'}"

    elif [[ "$stripped" == "label:"* ]]; then
      current_label="${stripped#label:}"
      current_label="${current_label#"${current_label%%[! ]*}"}"
      current_label="${current_label%"${current_label##*[! ]}"}"
      current_label="${current_label#\"}" current_label="${current_label%\"}"
      current_label="${current_label#\'}" current_label="${current_label%\'}"
    fi
  done < "$config"

  # Flush last item
  if [[ -n "$current_path" ]]; then
    printf '%s|%s\n' "$current_label" "$current_path"
  fi
}

# ---------------------------------------------------------------------------
# Main discovery sequence
# ---------------------------------------------------------------------------

# 1. Project-level (highest priority)
discover_from_dir "$REPO_ROOT/.claude/agents" "project"

# 2. User-level
discover_from_dir "$HOME/.claude/agents" "user"

# 3. Config-based additional sources
if [[ -n "$CONFIG_FILE" ]]; then
  CONFIG_FILE="${CONFIG_FILE/#\~/$HOME}"
  if [[ "$CONFIG_FILE" != /* ]]; then
    CONFIG_FILE="$REPO_ROOT/$CONFIG_FILE"
  fi

  while IFS='|' read -r label path; do
    [[ -z "$path" ]] && continue
    source_label="${label:-custom}"
    discover_from_dir "$path" "$source_label"
  done < <(parse_config_sources "$CONFIG_FILE")
fi

# ---------------------------------------------------------------------------
# Emit all records as JSON Lines via a single python3 invocation.
# Each RECORD is "name:::source:::description:::path" — fields passed as
# separate sys.argv arguments so no quoting or escaping issues.
# ---------------------------------------------------------------------------
if [[ ${#RECORDS[@]} -eq 0 ]]; then
  exit 0
fi

python3 -c "
import json, sys
for arg in sys.argv[1:]:
    parts = arg.split(':::', 3)
    if len(parts) != 4:
        continue
    name, source, description, path = parts
    print(json.dumps(
        {'name': name, 'source': source, 'description': description, 'path': path},
        separators=(',', ':')
    ))
" "${RECORDS[@]}"
