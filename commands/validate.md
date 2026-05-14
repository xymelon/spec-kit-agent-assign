---
description: Validate that all Claude Code and Codex agent assignments are correct and agents exist
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks
handoffs:
  - label: Reassign Agents
    agent: speckit.agent-assign.assign
    prompt: Reassign agents to fix validation issues
  - label: Execute With Agents
    agent: speckit.agent-assign.execute
    prompt: Execute tasks with assigned agents
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Verify that assignments in `agent-assignments.yml` are complete, consistent, and reference Claude Code or Codex agents that actually exist. This command is **READ-ONLY** - it does not modify any files. If issues are found, it suggests remediation actions.

## Outline

1. **Setup**: Run `{SCRIPT}` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Check Assignment File Exists**: Verify `agent-assignments.yml` exists in FEATURE_DIR.
   - If missing, **STOP** and report: "No agent-assignments.yml found. Run `/speckit.agent-assign.assign` first to generate agent assignments."

3. **Load Inputs**: Read the following files from FEATURE_DIR:
   - **REQUIRED**: `agent-assignments.yml` - the agent assignment mapping
   - **REQUIRED**: `tasks.md` - the task list to validate against
   - Parse `agent-assignments.yml` to extract:
     - `schema_version` if present. Missing means legacy v1.
     - `runtimes_scanned` if present
     - `agents_scanned` list
     - `assignments` mapping
   - Parse `tasks.md` to extract all task IDs.

4. **Normalize Assignment References**: Convert legacy references to the current format before validating.
   - `default` is always valid and means inline execution.
   - A reference already starting with `claude:` or `codex:` is already normalized.
   - A legacy unprefixed reference should be resolved against the current registry by name.
   - If a legacy unprefixed reference matches exactly one current agent, validate it but warn that the assignment file should be regenerated to write normalized ids.
   - If a legacy unprefixed reference matches multiple runtimes, mark it `AMBIGUOUS`.

5. **Rescan Agent Definitions**: Discover currently available definitions using the same hierarchy as the assign command.

   **Claude Code scanning priority**:
   1. `.claude/agents/*.md` in the repository root
   2. `~/.claude/agents/*.md` in the user's home directory

   **Codex scanning priority**:
   1. `.codex/agents/*.toml`
   2. `~/.codex/agents/*.toml`

   Build a **Current Agent Registry** keyed by normalized id. Preserve `runtime`, `name`, `source`, `description`, and source path for each row.

6. **Run Validation Checks**: Perform the following checks and record results:

   **Check 1 - Coverage**: Every task ID in tasks.md has a corresponding entry in `assignments`.
   - Status per task: `OK` (has assignment) or `UNASSIGNED` (missing from assignments)

   **Check 2 - Assignment Reference**: Every assignment is `default` or resolves to exactly one current registry entry.
   - Status per assignment: `OK`, `MISSING`, or `AMBIGUOUS`

   **Check 3 - Runtime Availability**: Each non-default assignment references a runtime that is currently discoverable.
   - Claude assignments require the matching `.claude/agents/*.md` or `~/.claude/agents/*.md` file.
   - Codex assignments require the matching `.codex/agents/*.toml` or `~/.codex/agents/*.toml` file.

   **Check 4 - Agent Conflicts**: No agent name appears at multiple priority levels in the same runtime with different definitions.
   - Status: `OK` or `CONFLICT`
   - Runtime prefixes allow `claude:backend-dev` and `codex:backend-dev` to coexist, but the report should still call out cross-runtime same-name entries for operator awareness.

   **Check 5 - Agent Drift**: Compare `agents_scanned` from the assignment file against the current registry.
   - Report any agents that were available during assignment but are now missing.
   - Report any new agents that were not available during assignment.
   - For legacy v1 files without ids, compare by name and source when possible.

   **Check 6 - Metadata Validity**:
   - Claude Code agent files must have valid YAML frontmatter with at least a `description` field.
   - Codex agent TOML files must be parseable TOML and should have a `description` field.

7. **Generate Validation Report**: Output a structured report:

   ```text
   ## Agent Assignment Validation Report

   **Feature**: <feature-name>
   **Assignment file**: <path to agent-assignments.yml>
   **Schema version**: 2
   **Validation time**: <timestamp>

   ### Summary

   | Metric               | Value |
   |----------------------|-------|
   | Total tasks          | 15    |
   | Assigned tasks       | 15    |
   | Unassigned tasks     | 0     |
   | Valid agents         | 12    |
   | Missing agents       | 0     |
   | Ambiguous references | 0     |
   | Conflicts            | 0     |
   | Agent drift detected | No    |

   ### Overall Status: PASS / FAIL

   ### Task Assignment Details

   | Task ID | Assigned Agent     | Runtime | Status    |
   |---------|--------------------|---------|-----------|
   | T001    | default            | inline  | OK        |
   | T002    | claude:backend-dev | claude  | OK        |
   | T003    | codex:api-dev      | codex   | OK        |

   ### Issues Found (if any)

   1. **MISSING**: Task T003 assigned to `codex:api-dev` which does not exist at any Codex hierarchy level
   2. **UNASSIGNED**: Task T010 has no entry in agent-assignments.yml
   3. **AMBIGUOUS**: Task T012 uses legacy reference `backend-dev`, but both `claude:backend-dev` and `codex:backend-dev` exist
   4. **CONFLICT**: Codex agent `helper` found at both project and user level with different descriptions
   5. **DRIFT**: `claude:api-dev` was available during assignment but has since been removed

   ### Recommended Actions

   - Run `/speckit.agent-assign.assign` to regenerate normalized assignments
   - Or manually edit `agent-assignments.yml` to use a specific normalized id such as `claude:<name>` or `codex:<name>`
   ```

8. **Final Verdict**:
   - **PASS**: All checks pass - safe to run `/speckit.agent-assign.execute`
   - **FAIL**: Issues found - list actionable remediation steps

   If PASS, suggest proceeding with `/speckit.agent-assign.execute`.
   If FAIL, suggest running `/speckit.agent-assign.assign` to fix issues.

Note: This command is strictly read-only. It does not modify `agent-assignments.yml`, `tasks.md`, or any agent files.
