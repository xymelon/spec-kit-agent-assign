---
description: Scan available Claude Code and Codex agents or skills and assign them to tasks in tasks.md
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
   - Do not require both runtimes to be present. It is valid for a project to have only Claude Code agents, only Codex agents/skills, or both.

3. **Scan Agent and Skill Definitions**: Discover all available specialist definitions and build a normalized registry. Each registry row must have:
   - `id`: stable assignment reference, including runtime prefix
   - `runtime`: `claude` or `codex`
   - `kind`: `agent` or `skill`
   - `name`: human-readable local name
   - `source`: source level such as `project`, `user`, or `builtin`
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
   2. **Project-level Codex skills**: `.agents/skills/*/SKILL.md`
   3. **Project-level Codex skills**: `.codex/skills/*/SKILL.md`
   4. **User-level Codex agents**: `~/.codex/agents/*.toml`
   5. **User-level Codex skills**: `~/.codex/skills/*/SKILL.md`
   6. **Built-in Codex agent roles**: `worker` and `explorer`

   For each Codex agent TOML file:
   - Parse `name` if present, otherwise use the filename without `.toml`
   - Parse `description` if present
   - Use assignment id `codex-agent:<name>`
   - If the same Codex agent name appears at multiple levels, keep only the highest-priority definition

   For each Codex `SKILL.md` file:
   - Parse YAML frontmatter to extract `name` if present, otherwise use the parent directory name
   - Parse `description` from frontmatter
   - Skip generated spec-kit workflow skills whose name starts with `speckit-` unless the user input explicitly asks to include workflow skills
   - Use assignment id `codex-skill:<name>`
   - Treat skills as specialist guidance, not as directly spawnable agents. During execution, a Codex skill assignment means the executor must use that skill before doing the task.

   Always add these built-in Codex agent rows when scanning Codex:
   - `codex-agent:worker`: general implementation worker for bounded, file-scoped tasks
   - `codex-agent:explorer`: read-only codebase investigation worker for discovery and analysis tasks

   Build an **Agent Registry** table:

   ```text
   | # | ID                   | Runtime | Kind  | Source  | Description                         |
   |---|----------------------|---------|-------|---------|-------------------------------------|
   | 1 | claude:backend-dev   | claude  | agent | project | Backend development specialist       |
   | 2 | codex-agent:worker   | codex   | agent | builtin | General implementation worker        |
   | 3 | codex-skill:playwright | codex | skill | user    | Browser automation skill             |
   ```

   If no specialist definitions are found for the selected runtime(s), **STOP** and report: "No agent or skill definition files found for the selected runtime(s). Since there are no specialized agents available, it is recommended to use `/speckit.implement` directly for task execution."

4. **Load Tasks**: Read tasks.md from FEATURE_DIR. Parse each task line following the checklist format:
   ```
   - [ ] [TaskID] [P?] [Story?] Description with file path
   ```
   Extract: Task ID, parallel marker, story label, description, and file paths mentioned.

5. **Auto-Match Specialists to Tasks**: For each task, analyze its description and file paths against each registry entry's description and capabilities. Consider:
   - File path patterns (for example, `src/api/` routes to API/backend specialists, `tests/` routes to test specialists)
   - Task action keywords (for example, "Create model" maps to backend, "Write test" maps to test-writer, "Implement UI" maps to frontend)
   - Runtime fit:
     - Prefer `claude:<name>` for Claude Code projects with matching named agents
     - Prefer `codex-agent:worker` for Codex implementation tasks without a more specific custom Codex agent
     - Prefer `codex-agent:explorer` only for read-only investigation, analysis, or planning tasks
     - Prefer `codex-skill:<name>` when the task clearly benefits from that skill's instructions or tools
   - Story context and phase. Setup tasks may need different specialists than implementation or polish tasks.

   Produce a proposed assignment for every task. If no specialist is a good fit, assign `default`.

6. **Present Assignments for Confirmation**: Display a summary table of all proposed assignments:

   ```text
   | Task ID | Description (truncated)          | Assigned Specialist | Reason                    |
   |---------|----------------------------------|---------------------|---------------------------|
   | T001    | Create project structure...       | default             | General setup task         |
   | T002    | Implement User model in src/...   | claude:backend-dev  | Data model creation        |
   | T003    | Build API route in src/api/...    | codex-agent:worker  | Bounded implementation     |
   | T004    | Validate browser flow...          | codex-skill:playwright | Browser verification    |
   ```

   **Ask the user**: "Review the proposed agent assignments above. You can:
   - **Accept all** - proceed with these assignments
   - **Modify** - specify changes (for example, 'T003 -> codex-agent:worker', 'T005 -> default')
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
       kind: "agent"
       name: "backend-dev"
       source: "project"
       description: "Backend development specialist"
     - id: "codex-agent:worker"
       runtime: "codex"
       kind: "agent"
       name: "worker"
       source: "builtin"
       description: "General implementation worker for bounded tasks"
     - id: "codex-skill:playwright"
       runtime: "codex"
       kind: "skill"
       name: "playwright"
       source: "user"
       description: "Browser automation skill"

   assignments:
     T001:
       agent: "default"
       reason: "General setup task, no specialized agent needed"
     T002:
       agent: "claude:backend-dev"
       reason: "Task involves data model creation, matches backend-dev capabilities"
     T003:
       agent: "codex-agent:worker"
       reason: "Bounded implementation task suitable for a Codex worker"
     T004:
       agent: "codex-skill:playwright"
       reason: "Task requires browser automation guidance"
   ```

   Write this file to `FEATURE_DIR/agent-assignments.yml`.

8. **Report**: Output a summary:
   - Path to generated `agent-assignments.yml`
   - Total tasks assigned
   - Breakdown by assignment id (count per specialist)
   - Number of tasks assigned to `default`
   - Runtimes scanned
   - Suggest running `/speckit.agent-assign.validate` to verify assignments

Note: This command requires tasks.md to exist. If it does not exist, suggest running `/speckit.tasks` first.
