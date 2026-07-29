#!/usr/bin/env bash
# Runs any `gh` subcommand authenticated as the mmio-claude-agent[bot] GitHub App
# instead of whatever personal account `gh auth status` has stored. Shared by
# BotIdentity.hook.sh for every gh subcommand whose "posted by" is determined by API
# auth rather than commit metadata -- PR creation, PR comments, issue comments.
#
# MMIO_GH_APP_ID / MMIO_GH_APP_INSTALLATION_ID / MMIO_GH_APP_PRIVATE_KEY_PATH are read
# from the canonical ~/.claude/.env (not this repo's own .env) so this works unmodified
# from any worktree checkout, which won't have its own copy of the repo's untracked
# .env. Namespaced with MMIO_ because that same global file also holds a second GitHub
# App's credentials (schoolshopla-claude-agent) under the unprefixed GH_APP_* names.
#
# Forwards all arguments to `gh` unchanged -- see docs/runbooks/ for how this is wired
# into Claude Code via BotIdentity.hook.sh.
set -euo pipefail

GLOBAL_ENV="$HOME/.claude/.env"
if [ ! -f "$GLOBAL_ENV" ]; then
  echo "gh_app_exec.sh: $GLOBAL_ENV not found -- can't read MMIO_GH_APP_* credentials" >&2
  exit 1
fi

MMIO_GH_APP_ID=$(grep -m1 '^MMIO_GH_APP_ID=' "$GLOBAL_ENV" | cut -d= -f2-)
MMIO_GH_APP_INSTALLATION_ID=$(grep -m1 '^MMIO_GH_APP_INSTALLATION_ID=' "$GLOBAL_ENV" | cut -d= -f2-)
MMIO_GH_APP_PRIVATE_KEY_PATH=$(grep -m1 '^MMIO_GH_APP_PRIVATE_KEY_PATH=' "$GLOBAL_ENV" | cut -d= -f2-)
export MMIO_GH_APP_ID MMIO_GH_APP_INSTALLATION_ID MMIO_GH_APP_PRIVATE_KEY_PATH

if [ -z "$MMIO_GH_APP_ID" ] || [ -z "$MMIO_GH_APP_INSTALLATION_ID" ] || [ -z "$MMIO_GH_APP_PRIVATE_KEY_PATH" ]; then
  echo "gh_app_exec.sh: MMIO_GH_APP_ID / MMIO_GH_APP_INSTALLATION_ID / MMIO_GH_APP_PRIVATE_KEY_PATH missing from $GLOBAL_ENV" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --no-env-file: on this host's kernel, bun's .env auto-probe crashes with statx
# ENOSYS (kernel 4.4 predates the statx syscall) if a .env file is present in cwd --
# see OPERATIONAL_RULES.md. Skipping the probe is the confirmed fix; harmless if this
# repo has no root .env.
TOKEN=$(bun --no-env-file "$REPO_ROOT/scripts/gh_app_token.ts")

GH_TOKEN="$TOKEN" gh "$@"
