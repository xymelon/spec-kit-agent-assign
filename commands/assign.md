---
description: Scan available Claude Code and Codex agents and assign them to tasks in tasks.md
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks
handoffs:
  - label: Validate Assignments
    agent: speckit.agent-assign.validate
    prompt: Validate all agent assignments
    send: true
  - label: Execute With Agents
    agent: speckit.agent-assign.execute
    prompt: Execute tasks with assigned agents
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `{SCRIPT}` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Detect Assignment Mode**: Decide which runtime registries to scan.
   - If user input contains `claude`, scan Claude Code definitions.
   - If user input contains `codex`, scan Codex definitions.
   - If user input is empty or does not name a runtime, scan both Claude Code and Codex definitions.
   - Do not require both runtimes to be present. It is valid for a project to have only Claude Code agents, only Codex agents, or both.

3. **Scan Agent Definitions**: Discover all available agent definitions and build a normalized registry. Each registry row must have:
   - `id`: stable assignment reference, including runtime prefix
   - `runtime`: `claude` or `codex`
   - `name`: human-readable local name
   - `source`: source level such as `project` or `user`
   - `description`: short capability summary

   **Claude Code scanning priority** (highest to lowest):
   1. **Project-level agents**: `.claude/agents/*.md`
   2. **User-level agents**: `~/.claude/agents/*.md`

   For each Claude Code agent file:
   - Parse YAML frontmatter to extract `name` if present, otherwise use the filename without `.md`
   - Parse `description` from frontmatter
   - Use assignment id `claude:<name>`
   - If the same Claude agent name appears at multiple levels, keep only the highest-priority definition

   **Codex scanning priority** (highest to lowest):
   1. **Project-level Codex agents**: `.codex/agents/*.toml`
   2. **User-level Codex agents**: `~/.codex/agents/*.toml`

   For each Codex agent TOML file:
   - Parse `name` if present, otherwise use the filename without `.toml`
   - Parse `description` if present
   - Use assignment id `codex:<name>`
   - If the same Codex agent name appears at multiple levels, keep only the highest-priority definition

   Build an **Agent Registry** table:

   ```text
   | # | ID                 | Runtime | Source  | Description                         |
   |---|--------------------|---------|---------|-------------------------------------|
   | 1 | claude:backend-dev | claude  | project | Backend development specialist       |
   | 2 | codex:api-dev      | codex   | project | Codex API implementation agent       |
   | 3 | codex:test-writer  | codex   | user    | Codex test authoring agent           |
   ```

   If no agent definitions are found for the selected runtime(s), **STOP** and report: "No agent definition files found for the selected runtime(s). Since there are no specialized agents available, it is recommended to use `/speckit.implement` directly for task execution."

4. **Load Tasks**: Read tasks.md from FEATURE_DIR. Parse each task line following the checklist format:
   ```
   - [ ] [TaskID] [P?] [Story?] Description with file path
   ```
   Extract: Task ID, parallel marker, story label, description, and file paths mentioned.

5. **Auto-Match Agents to Tasks**: For each task, analyze its description and file paths against each registry entry's description and capabilities. Consider:
   - File path patterns (for example, `src/api/` routes to API/backend agents, `tests/` routes to test agents)
   - Task action keywords (for example, "Create model" maps to backend, "Write test" maps to test-writer, "Implement UI" maps to frontend)
   - Runtime fit:
     - Prefer `claude:<name>` for Claude Code projects with matching named agents
     - Prefer `codex:<name>` for Codex projects with matching named agents
   - Story context and phase. Setup tasks may need different agents than implementation or polish tasks.

   Produce a proposed assignment for every task. If no agent is a good fit, assign `default`.

6. **Present Assignments for Confirmation**: Display a summary table of all proposed assignments:

   ```text
   | Task ID | Description (truncated)          | Assigned Agent     | Reason                    |
   |---------|----------------------------------|--------------------|---------------------------|
   | T001    | Create project structure...       | default            | General setup task         |
   | T002    | Implement User model in src/...   | claude:backend-dev | Data model creation        |
   | T003    | Build API route in src/api/...    | codex:api-dev      | API implementation         |
   ```

   **Ask the user**: "Review the proposed agent assignments above. You can:
   - **Accept all** - proceed with these assignments
   - **Modify** - specify changes (for example, 'T003 -> codex:api-dev', 'T005 -> default')
   - **Abort** - cancel without writing assignments"

   Wait for user response. Apply any requested changes before proceeding. Accept legacy unprefixed Claude agent names in user edits when they are unambiguous, but write normalized ids to the file.

7. **Write Agent Assignments File**: Generate `agent-assignments.yml` in FEATURE_DIR with the following structure:

   ```yaml
   # Agent Assignments
   # Feature: <feature-name from plan.md or branch name>
   # Generated: <timestamp>
   # Command: /speckit.agent-assign.assign

   schema_version: 2
   runtimes_scanned:
     - "claude"
     - "codex"
   agents_scanned:
     - id: "claude:backend-dev"
       runtime: "claude"
       name: "backend-dev"
       source: "project"
       description: "Backend development specialist"
     - id: "codex:api-dev"
       runtime: "codex"
       name: "api-dev"
       source: "project"
       description: "Codex API implementation agent"

   assignments:
     T001:
       agent: "default"
       reason: "General setup task, no specialized agent needed"
     T002:
       agent: "claude:backend-dev"
       reason: "Task involves data model creation, matches backend-dev capabilities"
     T003:
       agent: "codex:api-dev"
       reason: "API implementation aligns with api-dev capabilities"
   ```

   Write this file to `FEATURE_DIR/agent-assignments.yml`.

8. **Report**: Output a summary:
   - Path to generated `agent-assignments.yml`
   - Total tasks assigned
   - Breakdown by assignment id (count per agent)
   - Number of tasks assigned to `default`
   - Runtimes scanned
   - Suggest running `/speckit.agent-assign.validate` to verify assignments

Note: This command requires tasks.md to exist. If it does not exist, suggest running `/speckit.tasks` first.
