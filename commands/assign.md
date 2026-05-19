---
description: Scan available Claude Code agents and assign them to tasks in tasks.md
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

2. **Scan Agent Definitions**: Discover all available Claude Code agent definition files and build the Agent Registry.

   **Step 2a — Check for additional sources config**: Look for `.claude/agent-assign.yml` in the repository root. If found, it lists extra directories to scan under `additional_agent_sources`. The config is optional — its absence means only the standard two paths are scanned.

   **Step 2b — Run discovery script (preferred)**:

   Check whether the extension's discovery script is installed:

   ```sh
   ls .specify/extensions/agent-assign/scripts/bash/discover-agents.sh 2>/dev/null && echo "FOUND" || echo "NOT_FOUND"
   ```

   **If FOUND**, run it from the repository root:

   ```sh
   bash .specify/extensions/agent-assign/scripts/bash/discover-agents.sh \
     --repo-root "$(pwd)" \
     --config ".claude/agent-assign.yml"
   ```

   On Windows / PowerShell:

   ```powershell
   & ".specify\extensions\agent-assign\scripts\powershell\discover-agents.ps1" `
     -RepoRoot (Get-Location).Path `
     -Config "claude\agent-assign.yml"
   ```

   Each line of stdout is a JSON object. Collect all lines as the raw agent list:

   ```text
   {"name":"backend-dev","source":"project","description":"Backend specialist","path":"/abs/.claude/agents/backend-dev.md"}
   {"name":"test-writer","source":"user","description":"Test author","path":"/home/user/.claude/agents/test-writer.md"}
   {"name":"api-dev","source":"vscode-plugin","description":"REST API specialist","path":"/abs/plugin/agents/api-dev.md"}
   ```

   **If NOT FOUND**, fall back to inline discovery. Run:

   ```sh
   find "$(pwd)/.claude/agents" -maxdepth 1 -name "*.md" 2>/dev/null
   find "$HOME/.claude/agents" -maxdepth 1 -name "*.md" 2>/dev/null
   ```

   For each file found, read its YAML frontmatter using the Read tool. Extract `name` (fall back to the filename stem if `name:` is absent from frontmatter) and `description`. Note the source level (`project` for the first path, `user` for the second). Apply deduplication manually: if the same agent name appears in both directories, keep only the project-level entry. Config-sourced additional paths are not scanned in fallback mode.

   **Step 2c — Build Agent Registry**: Parse the collected JSON objects (script mode) or manual scan results (fallback mode) into the Agent Registry table:

   ```text
   | # | Agent Name      | Source       | Description                              |
   |---|-----------------|--------------|------------------------------------------|
   | 1 | backend-dev     | project      | Backend development specialist            |
   | 2 | frontend-dev    | project      | Frontend React/TypeScript specialist      |
   | 3 | test-writer     | user         | Unit and integration test author          |
   | 4 | api-dev         | vscode-plugin| REST API design and implementation        |
   ```

   If no agent definition files are found at any level, **STOP** and report: "No agent definition files found at any hierarchy level. Since there are no specialized agents available, it is recommended to use `/speckit.implement` directly for task execution."

3. **Load Tasks**: Read tasks.md from FEATURE_DIR. Parse each task line following the checklist format:
   ```
   - [ ] [TaskID] [P?] [Story?] Description with file path
   ```
   Extract: Task ID, parallel marker, story label, description, and file paths mentioned.

4. **Auto-Match Agents to Tasks**: For each task, analyze its description and file paths against each agent's description and capabilities. Consider:
   - File path patterns (e.g., `src/api/` → API agent, `src/models/` → backend agent, `tests/` → test agent)
   - Task action keywords (e.g., "Create model" → backend, "Write test" → test-writer, "Implement UI" → frontend)
   - Story context and phase (Setup tasks may need a different agent than Polish tasks)

   Produce a proposed assignment for every task. If no agent is a good fit, assign `default`.

5. **Present Assignments for Confirmation**: Display a summary table of all proposed assignments:

   ```text
   | Task ID | Description (truncated)          | Assigned Agent  | Reason                    |
   |---------|----------------------------------|-----------------|---------------------------|
   | T001    | Create project structure...       | default         | General setup task         |
   | T002    | Implement User model in src/...   | backend-dev     | Data model creation        |
   | T003    | Write API endpoint in src/api/... | backend-dev     | API implementation         |
   | T004    | Create React component in src/... | frontend-dev    | UI component development   |
   | T005    | Write unit tests for...           | test-writer     | Test authoring             |
   ```

   **Ask the user**: "Review the proposed agent assignments above. You can:
   - **Accept all** — proceed with these assignments
   - **Modify** — specify changes (e.g., 'T003 → api-specialist', 'T005 → default')
   - **Abort** — cancel without writing assignments"

   Wait for user response. Apply any requested changes before proceeding.

6. **Write Agent Assignments File**: Generate `agent-assignments.yml` in FEATURE_DIR with the following structure:

   ```yaml
   # Agent Assignments
   # Feature: <feature-name from plan.md or branch name>
   # Generated: <timestamp>
   # Command: /speckit.agent-assign.assign

   agents_scanned:
     - name: "backend-dev"
       source: "project"
       description: "Backend development specialist"
     - name: "frontend-dev"
       source: "project"
       description: "Frontend React/TypeScript specialist"

   assignments:
     T001:
       agent: "default"
       reason: "General setup task, no specialized agent needed"
     T002:
       agent: "backend-dev"
       reason: "Task involves data model creation, matches backend-dev capabilities"
     T003:
       agent: "backend-dev"
       reason: "API endpoint implementation aligns with backend-dev skills"
   ```

   Write this file to `FEATURE_DIR/agent-assignments.yml`.

7. **Report**: Output a summary:
   - Path to generated `agent-assignments.yml`
   - Total tasks assigned
   - Breakdown by agent (count per agent)
   - Number of tasks assigned to `default`
   - Suggest running `/speckit.agent-assign.validate` to verify assignments

Note: This command requires tasks.md to exist. If it does not exist, suggest running `/speckit.tasks` first.
