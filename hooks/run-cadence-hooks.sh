#!/usr/bin/env bash
# Dispatch to cadence-hooks binary on PATH. Fails open if not found (ADR 0008)
# or if the installed binary predates the requested subcommand (cadence-hooks#39 P0).
# Usage: run-cadence-hooks.sh <subcommand> [args...]
set -euo pipefail

BINARY=$(command -v cadence-hooks 2>/dev/null || true)

if [ -z "$BINARY" ]; then
  exit 0
fi

# Capture stderr to a file so we can inspect it for the stale-binary signature.
# Plain redirection, not process substitution — `set -euo pipefail` plus
# process substitution races on exit status.
err_file=$(mktemp)
trap 'rm -f "$err_file"' EXIT

rc=0
"$BINARY" "$@" 2>"$err_file" || rc=$?

# Stale-binary signatures: clap v4 says "unrecognized subcommand", clap v3 said
# "The subcommand '...' wasn't recognized". Match both so the fail-open holds
# regardless of which clap generation built the installed binary.
if [ "$rc" -ne 0 ] && grep -qiE "unrecognized subcommand|wasn't recognized" "$err_file"; then
  # Binary is installed but stale: this subcommand doesn't exist in it yet.
  # Fail open instead of blocking every matching tool call until upgrade.
  exit 0
fi

cat "$err_file" >&2
exit "$rc"
