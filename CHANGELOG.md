# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-31

### Added

- `speckit.agent-assign.assign` — Scan Claude Code agent definitions and assign them to tasks
- `speckit.agent-assign.validate` — Read-only validation of agent assignments before execution
- `speckit.agent-assign.execute` — Phase-by-phase task execution with specialized agent spawning
- Agent discovery following Claude Code's priority hierarchy (project > user)
- YAML-based assignment storage (`agent-assignments.yml`)
- `after_tasks` hook for automatic agent assignment after task generation
- Parallel task execution support for tasks marked with `[P]`
- Fallback to `default` mode when assigned agent is unavailable

[1.0.0]: https://github.com/xymelon/spec-kit-agent-assign/releases/tag/v1.0.0
