# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A [Spec-Kit](https://github.com/github/spec-kit/) extension that adds agent assignment capabilities to the task execution workflow. It allows tasks in `tasks.md` to be assigned to specialized Claude Code agents, Codex agents, or Codex skills, validated, and executed with focused context.

Three commands:
- `/speckit.agent-assign.assign` — Scan available Claude Code and Codex specialists and assign them to tasks
- `/speckit.agent-assign.validate` — Validate that all assignments are correct and specialists exist
- `/speckit.agent-assign.execute` — Execute tasks with the assigned agent or skill guidance

## Extension Structure

```
├── extension.yml          # Extension manifest
└── commands/
    ├── assign.md          # Agent assignment command
    ├── validate.md        # Assignment validation command
    └── execute.md         # Agent-powered execution command
```

- Extension ID: `agent-assign`
- Command naming pattern: `speckit.agent-assign.<command>`
- Manifest schema version: `"1.0"`

## Agent Scanning Hierarchy

Agent definitions are discovered using runtime-specific priority (high overrides low):

Claude Code:
1. **Project-level agents**: `.claude/agents/*.md`
2. **User-level agents**: `~/.claude/agents/*.md`

Codex:
1. **Project-level agents**: `.codex/agents/*.toml`
2. **Spec-kit project skills**: `.agents/skills/*/SKILL.md` (generated `speckit-*` workflow skills are skipped by default)
3. **Project-level skills**: `.codex/skills/*/SKILL.md`
4. **User-level agents**: `~/.codex/agents/*.toml`
5. **User-level skills**: `~/.codex/skills/*/SKILL.md`
6. **Built-in roles**: `worker`, `explorer`

Same-name specialists at higher priority override lower ones within the same runtime/kind. Cross-runtime names coexist by using normalized ids.

## Agent Assignment Storage

Assignments are stored in `agent-assignments.yml` in the feature directory (alongside tasks.md):
```yaml
agents_scanned:
  - id: "claude:agent-name"
    runtime: "claude"
    kind: "agent"
    name: "agent-name"
    source: "project"
    description: "Agent description"
assignments:
  T001:
    agent: "claude:agent-name"
    reason: "Why this agent was chosen"
```

## Command Format

Commands follow the [spec-kit extension command format](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md):
- YAML frontmatter with `description` and optional `handoffs`
- `$ARGUMENTS` placeholder for user input
- Pre/post-execution hook checking blocks (pattern from `.specify/extensions.yml`)
- Numbered step-by-step outline
- Commands depend on `check-prerequisites.sh --json --require-tasks` for feature context (returns `FEATURE_DIR`, `AVAILABLE_DOCS`, etc.)
