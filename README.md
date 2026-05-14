# spec-kit-agent-assign

<div align="center">
  <strong>Route the right task to the right agent.</strong>
  <br/><br/>

  [![spec-kit extension](https://img.shields.io/badge/spec--kit-extension-blue)](https://github.com/github/spec-kit)
  [![Category: process](https://img.shields.io/badge/category-process-green)](https://github.com/github/spec-kit)
  [![Effect: Read+Write](https://img.shields.io/badge/effect-Read%2BWrite-orange)](https://github.com/github/spec-kit)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
</div>

<br/>

Your `tasks.md` has 20 tasks. Some need a backend specialist, some need a frontend expert, some need a test writer. But `/speckit.implement` runs them all in one flat context. This extension fixes that — it scans Claude Code agents and Codex agents/skills, assigns each task to the best-fit specialist, and executes them with focused context.

![Concurrent execution of specialized agents](./agents.png)

## The Problem

Spec-kit's standard `/speckit.implement` runs all tasks sequentially in a single agent context. This works for small projects, but as complexity grows:

- A backend task gets implemented without deep backend expertise
- Test tasks lack awareness of testing best practices
- Frontend and backend tasks compete for the same context window
- No task-level specialization — every task gets the same generalist treatment

As projects scale, this one-size-fits-all approach leaves room for improvement.

## The Solution

```
/speckit.agent-assign.assign

Agent Registry
| # | ID                 | Runtime | Kind  | Source  | Description                         |
|---|--------------------|---------|-------|---------|-------------------------------------|
| 1 | claude:backend-dev | claude  | agent | project | Backend development specialist       |
| 2 | codex-agent:worker | codex   | agent | builtin | General implementation worker        |
| 3 | codex-skill:playwright | codex | skill | user | Browser automation skill             |

Task Assignments
| Task ID | Description                    | Assigned Specialist | Reason                    |
|---------|--------------------------------|---------------------|---------------------------|
| T001    | Create project structure...    | default             | General setup task         |
| T002    | Implement User model...        | claude:backend-dev  | Data model creation        |
| T003    | Create API endpoint...         | codex-agent:worker  | Bounded implementation     |
| T004    | Verify browser flow...         | codex-skill:playwright | Browser automation      |

Assignments written to: .specify/features/my-feature/agent-assignments.yml
```

## Benchmark: Agent-Assign vs Standard Spec-Kit

We built the same project — [TuneMuse](https://github.com/xymelon/tune-muse), an AI-powered music recommendation app — twice:

- **Plan A** ([tune-muse](https://github.com/xymelon/tune-muse)): Standard spec-kit workflow using `/speckit.implement`
- **Plan B** ([tune-muse-assign](https://github.com/xymelon/tune-muse-assgin)): Same `tasks.md`, executed with `spec-kit-agent-assign`

Three frontier models (Gemini 3.1 Pro, GPT-5-4, Claude Opus 4.6) evaluated both implementations across three dimensions. Each dimension was scored 1–10.

### Evaluation Dimensions

| Dimension | What it measures |
|-----------|-----------------|
| **Result Quality** | Spec/plan/task completeness, code quality, test coverage, runnability and maintainability |
| **Task Execution** | Adherence to `tasks.md`, reduced skipped/faked steps, dependency handling, less rework |
| **Overall Value** | Quality improvement vs. added complexity, reusability, long-term maintenance worthiness |

### Detailed Scores

| Dimension | Gemini 3.1 Pro | GPT-5-4 | Opus 4.6 |
|-----------|---------------|---------|----------|
| Result Quality | A:6 / B:**9** (+3) | A:6 / B:**8** (+2) | A:5 / B:**7.5** (+2.5) |
| Task Execution | A:5 / B:**9** (+4) | A:6 / B:**7** (+1) | A:4.5 / B:**6** (+1.5) |
| Overall Value | A:6 / B:**8.5** (+2.5) | A:6 / B:**7.5** (+1.5) | A:5 / B:**7** (+2) |
| **Total (out of 30)** | A:17 / B:**26.5** | A:18 / B:**22.5** | A:14.5 / B:**20.5** |
| **B's Lead** | **+9.5** | **+4.5** | **+6** |

### Cross-Model Averages

| Dimension | Plan A Avg | Plan B Avg | Delta |
|-----------|-----------|-----------|-------|
| Result Quality | 5.7 | **8.2** | **+2.5** |
| Task Execution | 5.2 | **7.3** | **+2.1** |
| Overall Value | 5.7 | **7.7** | **+2.0** |
| **Total** | **16.5** | **23.2** | **+6.7** |

**Plan B leads by ~+2.2 points per dimension on average, with a 40% higher total score.**

### Model Consensus

| Question | Gemini 3.1 Pro | GPT-5-4 | Opus 4.6 |
|----------|---------------|---------|----------|
| Is B better than A? | Significantly better | Better | Clearly better |
| Worth long-term maintenance? | Strongly recommended | Concept worth keeping | Recommended, needs iteration |
| Highest-value aspect | YAML-driven routing + context-isolated execution | Task-level specialization with parallel execution | Specialized agent spawning in the execute phase |

## Quick Start

> **Need ready-made agents?** Claude Code users can bootstrap `.claude/agents/` with the open-source [agency-agents](https://github.com/msitarzewski/agency-agents) collection. Codex users can rely on built-in `worker`/`explorer` roles, user agents in `~/.codex/agents/*.toml`, and project skills in `.agents/skills/*/SKILL.md`.

```bash
# Install the extension
specify extension add agent-assign --from https://github.com/xymelon/spec-kit-agent-assign/archive/refs/heads/main.zip

# Generate tasks as usual
/speckit.tasks

# Assign agents to tasks
/speckit.agent-assign.assign

# Validate assignments
/speckit.agent-assign.validate

# Execute with specialized agents
/speckit.agent-assign.execute
```

## Commands

| Command | What it does |
|---------|--------------|
| `speckit.agent-assign.assign` | Scan available Claude Code and Codex specialists and assign them to tasks |
| `speckit.agent-assign.validate` | Validate that all assignments are correct and specialists exist |
| `speckit.agent-assign.execute` | Execute tasks with the assigned agent or skill guidance |

## How It Works

### 1. Assign

Scans both Claude Code agent definitions and Codex agent/skill definitions. Assignment ids are normalized with runtime prefixes so same-name specialists can coexist.

| Runtime | Priority | Location | Scope |
|---------|----------|----------|-------|
| Claude Code | High | `.claude/agents/*.md` | Project-level named agents |
| Claude Code | Low | `~/.claude/agents/*.md` | User-level named agents |
| Codex | High | `.codex/agents/*.toml` | Project-level Codex agents |
| Codex | High | `.agents/skills/*/SKILL.md` | Project skills for Codex; generated `speckit-*` workflow skills are skipped by default |
| Codex | Medium | `.codex/skills/*/SKILL.md` | Project-level Codex skills |
| Codex | Low | `~/.codex/agents/*.toml` | User-level Codex agents |
| Codex | Low | `~/.codex/skills/*/SKILL.md` | User-level Codex skills |
| Codex | Built-in | `worker`, `explorer` | Built-in Codex agent roles |

Same-name specialists at higher priority override lower ones within the same runtime/kind. Each task is auto-matched to the best-fit specialist based on:
- **File path patterns** — `src/api/` routes to API agents, `tests/` routes to test agents
- **Task action keywords** — "Create model" maps to backend, "Write test" maps to test-writer
- **Story context** — Setup tasks may need different agents than implementation tasks

Assignments are stored in `agent-assignments.yml` alongside `tasks.md`:

```yaml
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

assignments:
  T001:
    agent: "default"
    reason: "General setup task, no specialized agent needed"
  T002:
    agent: "claude:backend-dev"
    reason: "Data model creation matches backend-dev capabilities"
  T003:
    agent: "codex-agent:worker"
    reason: "Bounded implementation task suitable for a Codex worker"
```

### 2. Validate

A read-only check that catches problems before execution:

- **Coverage** — every task in `tasks.md` has an assignment
- **Specialist existence** — every assigned agent or skill still exists
- **Agent drift** — detects agents or skills added or removed since assignment
- **Conflicts** — same specialist name at multiple hierarchy levels
- **Metadata validity** — Claude/Codex Markdown frontmatter and Codex TOML metadata are parseable

### 3. Execute

Replaces `/speckit.implement` with agent-aware execution:

- Tasks assigned to `default` run inline (same as standard implement)
- Tasks assigned to `claude:<name>` use the matching Claude Code agent
- Tasks assigned to `codex-agent:<name>` use Codex multi-agent tooling when available
- Tasks assigned to `codex-skill:<name>` apply that Codex skill's guidance before execution
- Phase ordering, dependency tracking, and `[P]` parallel markers are all respected
- Progress is tracked in `tasks.md` with per-task and per-phase reporting

```
Phase 2: Foundational — Complete (5/5 tasks)
  T002 (claude:backend-dev)  — Implemented User model
  T003 (codex-agent:worker)  — Created API endpoints
  T004 (codex-skill:playwright) — Verified browser flow
  T005 (default) — Added routing layer
  T006 (claude:test-writer)  — Wrote integration tests
```

## Workflow Integration

This extension slots into the standard spec-kit pipeline, replacing the final implementation step:

```
/speckit.constitution            → constitution.md      (project principles)
/speckit.specify                 → spec.md              (what to build)
/speckit.plan                    → plan.md              (how to build it)
/speckit.tasks                   → tasks.md             (actionable task list)
/speckit.agent-assign.assign     → agent-assignments.yml     ← NEW
/speckit.agent-assign.validate   → validation report         ← NEW
/speckit.agent-assign.execute    → implemented project       ← REPLACES /speckit.implement
```

The `after_tasks` hook can automatically trigger agent assignment after task generation, making the transition seamless.

## Installation

```bash
# From latest release
specify extension add agent-assign --from https://github.com/xymelon/spec-kit-agent-assign/archive/refs/tags/v1.1.0.zip

# From main branch (latest, includes unreleased changes)
specify extension add agent-assign --from https://github.com/xymelon/spec-kit-agent-assign/archive/refs/heads/main.zip

# Development mode (local clone)
specify extension add --dev /path/to/spec-kit-agent-assign
```

**Requirements**: spec-kit >= 0.7.1

## Configuration

No extension-specific configuration is required. The extension discovers specialists from the conventions used by the active coding agent.

For Claude Code, agent definitions are standard Claude Code agent files (`.claude/agents/*.md` and `~/.claude/agents/*.md`):

```bash
# Example: create a backend specialist agent
cat > .claude/agents/backend-dev.md << 'EOF'
---
description: Backend development specialist for Python/FastAPI
---

You are a backend development specialist...
EOF
```

Or use the [agency-agents](https://github.com/msitarzewski/agency-agents) library to quickly populate your agent roster with battle-tested definitions.

For Codex, spec-kit installs commands as skills under `.agents/skills/*/SKILL.md`. This extension also discovers Codex project agents under `.codex/agents/*.toml`, user agents under `~/.codex/agents/*.toml`, project/user Codex skills, and the built-in `worker` and `explorer` roles. Generated `speckit-*` workflow command skills are skipped by default so they do not crowd the task-specialist registry.

```bash
# Example: a project Codex skill discovered as codex-skill:backend-review
mkdir -p .agents/skills/backend-review
cat > .agents/skills/backend-review/SKILL.md << 'EOF'
---
name: backend-review
description: Backend review guidance for API, data model, and persistence tasks
---

Use this skill for backend implementation and review tasks.
EOF
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No agent or skill definition files found" | Create Claude files in `.claude/agents/`, Codex agent TOML files in `.codex/agents/`, or Codex skills in `.agents/skills/*/SKILL.md` |
| "No agent-assignments.yml found" | Run `/speckit.agent-assign.assign` before validate or execute |
| Agent drift detected during validation | Re-run `/speckit.agent-assign.assign` to update assignments |
| Ambiguous legacy assignment | Re-run `/speckit.agent-assign.assign` so assignments use normalized ids like `claude:<name>` or `codex-agent:<name>` |
| Task assigned to missing agent or skill | The execute command falls back to `default` mode with a warning when safe |

## Why This Matters

AI coding agents perform better with focused context. When a single agent handles everything:

1. Context window fills with irrelevant information
2. No domain expertise is applied to specialized tasks
3. Task execution becomes a flat checklist with no specialization
4. Quality degrades as the project grows

**spec-kit-agent-assign routes each task to a purpose-built agent**, so backend tasks get backend expertise, test tasks get testing expertise, and the overall implementation quality goes up — measurably.

---

Built for [spec-kit](https://github.com/github/spec-kit) | MIT License
