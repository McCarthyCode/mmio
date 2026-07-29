#!/usr/bin/env bash
# Thin wrapper kept for backwards compat with BotIdentity.hook.sh's existing rewrite --
# the actual GitHub App token-minting logic lives in scripts/gh_app_exec.sh, shared
# with `gh pr comment` / `gh issue comment` routing.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$REPO_ROOT/scripts/gh_app_exec.sh" pr create "$@"
