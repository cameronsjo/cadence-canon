# cadence-canon

Multi-session coordination for Claude Code — session identity, peer disclosure, and lane warnings for concurrent sessions sharing one repo checkout.

> A **canon** is the same melody entering at offset times, harmonious by construction. That is literally what parallel Claude Code sessions are — when they can hear each other.

## The Problem

Concurrent Claude Code sessions in one repo cannot see each other. Branch position and working-tree state silently expire the moment another session acts — and the first symptom is a commit landing on someone else's branch.

## What It Does

| Piece | Mechanism |
|---|---|
| **Identity** | Each session registers a file in `<repo>/.claude/sessions/` at start — deterministic adjective-noun name (`swift-tempo`, `quiet-loom`), branch, declared intent and paths |
| **Liveness** | File mtime is the heartbeat. Crashed sessions just go stale (10 min) and get swept — no ceremony |
| **Disclosure** | New sessions get an `additionalContext` block naming live peers, their lanes, and the coordination protocol |
| **Lane warnings** | PreToolUse nudges (never blocks) on branch switches, blanket staging, and writes inside a peer's declared paths |
| **Coordination skill** | `cadence:coordinating-sessions` — the full protocol, commands, and collision recovery |

Registry files are auto-excluded from git via `.git/info/exclude` — they never appear in `git status`.

## Requirements

- [`cadence-hooks`](https://github.com/cameronsjo/cadence-hooks) **>= 0.14.0** on PATH (`brew install cameronsjo/tap/cadence-hooks`)
- The [cadence](https://github.com/cameronsjo/cadence) plugin (dependency)

## Hooks

| Hook | Event | Behavior |
|---|---|---|
| `session start` | SessionStart | Register self, sweep stale, disclose live peers |
| `session heartbeat` | PostToolUse (git/Edit/Write) | Touch own registry file, record branch drift |
| `session guard` | PreToolUse (git/Edit/Write) | Warn on branch switch, blanket staging, peer-lane writes |

Plus two CLI actions (not hooks): `cadence-hooks session declare` and `cadence-hooks session status`.

## Configuration

| Variable | Purpose |
|---|---|
| `CADENCE_SESSION_STALE_MINUTES` | Heartbeat-silence threshold before a session is presumed dead (default 10) |
| `CADENCE_DISABLE=start,heartbeat,guard` | Disable individual hooks |

## Design

Design doc and motivating incident: [claude-configurations](https://github.com/cameronsjo/claude-configurations) `docs/plans/2026-06-02-session-identity-coordination.md`. Hook implementation: [cameronsjo/cadence-hooks#54](https://github.com/cameronsjo/cadence-hooks/issues/54).

## License

BSL-1.1
