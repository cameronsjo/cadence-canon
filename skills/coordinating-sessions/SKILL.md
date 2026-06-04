---
name: coordinating-sessions
description: Use when a session-start disclosure names a live peer session, when cadence-hooks session status shows another session in this repo, or when the user says parallel Claude sessions are running in this checkout
license: BSL-1.1
metadata:
  author: cameronsjo
---

# Coordinating Sessions

## Overview

Concurrent Claude Code sessions share one checkout. Branch position, index, and
working tree are **shared mutable state** — any read of them expires the moment
another writer exists.

**Core principle:** re-verify, never assume. A gather from a previous turn is
already stale.

This protocol exists because of a real collision: an end-of-session commit
landed on a concurrent session's feature branch because the branch was checked
minutes earlier instead of in the same turn. Recovery worked; prevention is
cheaper.

## When to Use

- The session-start disclosure says another session is live in this repo
- `cadence-hooks session status` lists a live peer
- The user says sessions are running in parallel here

**NOT for:** coordinating subagents or teams *within* one session (that is
`cadence:agent-teams`), or sessions in separate git worktrees (separate working
trees cannot collide on checkout state).

## The Protocol

This is a discipline skill — follow exactly, do not adapt away the rules.

| # | Rule | Why |
|---|------|-----|
| 1 | **Declare your lane** as soon as you know what you're working on | Peers can only avoid you if you say where you are |
| 2 | **Re-verify branch + `git status` in the same turn as every mutation** | State from a previous turn is stale by definition |
| 3 | **Never switch branches** | The peer's working tree depends on the current branch |
| 4 | **Explicit-path `git add` only** — never `-A`, `-a`, or `git add .` | Blanket staging sweeps the peer's in-progress files into your commit |
| 5 | **Read the `[branch sha]` line in every `git commit` output** | It is a free collision alarm — an unexpected branch name means you just committed onto the peer's work |
| 6 | **Deliver cross-branch files via `gh api`, not checkout** | Writes can land on any branch without moving the working tree |
| 7 | **Lane overlap → stop and tell the user** | Two sessions needing the same files is a sequencing decision only the user can make |

## Commands

```bash
# Who else is here?
cadence-hooks session status

# Declare your lane (peers see this in their disclosures and guards)
cadence-hooks session declare --intent "cadence-hooks#54" --touching "crates/session/"

# Clear a stale declaration (blank value = explicit clear)
cadence-hooks session declare --intent "" --touching ""
```

Declare when work starts, re-declare when scope changes, clear when a task
finishes mid-session.

## Cross-Branch Delivery (Rule 6)

When a file must land on a branch that is not checked out:

```bash
# Create or update a file on any branch without touching the working tree
gh api -X PUT "repos/OWNER/REPO/contents/PATH" \
  -f message="commit message" \
  -f content="$(base64 < localfile)" \
  -f branch="target-branch"
# Updating an existing file additionally requires -f sha="$(gh api repos/OWNER/REPO/contents/PATH?ref=target-branch --jq .sha)"
```

**Materialize the payload outside the repo** (`/tmp/`, never the shared working
tree). Writing it into the checkout drops an untracked file into the peer's
tree and tempts a local `git add` — recreating the exact hazard Rule 6 avoids.

**After delivery, tell the user** the target branch moved on remote; the local
copy of that branch is now behind and needs a `git pull` whenever a session is
legitimately on it next.

## Collision Recovery

If a commit lands on a peer's branch anyway (Rule 5 caught it):

1. `git reset HEAD~1` — **mixed** reset: moves the branch pointer back, leaves
   every working-tree file (theirs and yours) untouched
2. Remove your orphaned file(s) from their tree
3. Deliver your content via `gh api` (Rule 6)
4. Verify the peer's work after every step: `git log --oneline -2` + `git status --short`

The bar: the other session never notices.

## Conclusion

When the peer finishes (its registry entry is deleted or goes stale), the user
may `/rewind` this session to the disclosure point and say "resolved". Re-check
the room with `cadence-hooks session status` — an empty room means full lanes.

## Common Mistakes

| Mistake | Reality |
|---|---|
| "The repo was on main a few minutes ago" | That read is stale. Re-verify in this turn. |
| "I'll just switch branches quickly and switch back" | The peer can act in between. Use `gh api`. |
| "`git add -A` is fine, I only changed one file" | The *peer's* uncommitted files are also in the tree. |
| "The peer looks stale, I'll ignore it" | Stale means *presumed* dead. If its branch matches the checkout, treat it as live until the user confirms. |
| "The user told me to commit to main" | The user named a **destination**, not a **method**. Rule 6 reaches main without a checkout. A user instruction naming a branch never authorizes a branch switch. |
