# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A [Spec-Kit](https://github.com/github/spec-kit/) extension that adds agent assignment capabilities to the task execution workflow. It allows tasks in `tasks.md` to be assigned to specialized Claude Code agents, validated, and executed via dedicated subagents.

Three commands:
- `/speckit.agent-assign.assign` — Scan available agent definitions and assign them to tasks
- `/speckit.agent-assign.validate` — Validate that all assignments are correct and agents exist
- `/speckit.agent-assign.execute` — Execute tasks by launching the assigned agent for each task

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

Agent definitions are discovered following Claude Code's official priority (high overrides low):
1. **Project-level**: `.claude/agents/*.md`
2. **User-level**: `~/.claude/agents/*.md`

Same-name agents at higher priority override lower ones.

## Agent Assignment Storage

Assignments are stored in `agent-assignments.yml` in the feature directory (alongside tasks.md):
```yaml
agents_scanned:
  - name: "agent-name"
    source: "project"
    description: "Agent description"
assignments:
  T001:
    agent: "agent-name"
    reason: "Why this agent was chosen"
```

## Command Format

Commands follow the [spec-kit extension command format](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md):
- YAML frontmatter with `description` and optional `handoffs`
- `$ARGUMENTS` placeholder for user input
- Pre/post-execution hook checking blocks (pattern from `.specify/extensions.yml`)
- Numbered step-by-step outline
- Commands depend on `check-prerequisites.sh --json --require-tasks` for feature context (returns `FEATURE_DIR`, `AVAILABLE_DOCS`, etc.)
