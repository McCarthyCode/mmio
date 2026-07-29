#!/bin/bash
# Bot-identity enforcement hook for Claude Code PreToolUse:Bash, scoped to this repo.
#
# Rewrites commands the ASSISTANT issues (never `!`-prefixed human passthrough, which
# never reaches PreToolUse at all) so agent-authored git commits, PRs, and PR/issue
# comments carry the mmio-claude-agent[bot] GitHub App identity instead of the human's
# own. See docs/runbooks/ and AGENTS.md for why this exists.
#
# - `git commit` -> gets a one-off `-c user.name=/-c user.email=` override (never
#   touches any config file, so it can't leak into the human's own commits).
# - `gh pr create` / `gh pr comment` / `gh issue comment` -> routed through
#   scripts/gh_app_exec.sh, which mints a fresh GitHub App installation token and runs
#   `gh` authenticated as the bot (git config alone can't do this -- who "posted"
#   something via the API is determined by API auth, not commit metadata).
#
# Known gap: a bare `gh api` call that happens to post a comment isn't covered -- only
# the `gh pr comment` / `gh issue comment` subcommand forms are matched.

if ! command -v jq &>/dev/null; then
  exit 0
fi

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Skip multi-line / heredoc commands -- the string surgery below assumes single-line.
case "$CMD" in
  *$'\n'*|*'<<'*) exit 0 ;;
esac

BOT_NAME="mmio-claude-agent[bot]"
BOT_EMAIL="308820401+mmio-claude-agent[bot]@users.noreply.github.com"

# Strip leading env var assignments for pattern matching, preserve them in the rewrite.
ENV_PREFIX=$(echo "$CMD" | grep -oE '^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)+' || echo "")
if [ -n "$ENV_PREFIX" ]; then
  CMD_BODY="${CMD:${#ENV_PREFIX}}"
else
  CMD_BODY="$CMD"
fi

REWRITTEN=""

if echo "$CMD_BODY" | grep -qE '^git[[:space:]]+commit([[:space:]]|$)'; then
  # Idempotent: already rewritten (or manually bot-authored) -- leave alone.
  if ! echo "$CMD_BODY" | grep -qF "$BOT_EMAIL"; then
    REST="${CMD_BODY#git}"
    REWRITTEN="${ENV_PREFIX}git -c user.name=\"${BOT_NAME}\" -c user.email=\"${BOT_EMAIL}\"${REST}"
  fi
else
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  GH_APP_EXEC="${REPO_ROOT}/scripts/gh_app_exec.sh"
  if [ -n "$REPO_ROOT" ] && [ -x "$GH_APP_EXEC" ]; then
    if echo "$CMD_BODY" | grep -qE '^gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
      REST="${CMD_BODY#gh pr create}"
      REWRITTEN="${ENV_PREFIX}${GH_APP_EXEC} pr create${REST}"
    elif echo "$CMD_BODY" | grep -qE '^gh[[:space:]]+pr[[:space:]]+comment([[:space:]]|$)'; then
      REST="${CMD_BODY#gh pr comment}"
      REWRITTEN="${ENV_PREFIX}${GH_APP_EXEC} pr comment${REST}"
    elif echo "$CMD_BODY" | grep -qE '^gh[[:space:]]+issue[[:space:]]+comment([[:space:]]|$)'; then
      REST="${CMD_BODY#gh issue comment}"
      REWRITTEN="${ENV_PREFIX}${GH_APP_EXEC} issue comment${REST}"
    fi
  fi
fi

if [ -z "$REWRITTEN" ]; then
  exit 0
fi

ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "Bot identity rewrite (mmio-claude-agent[bot])",
      "updatedInput": $updated
    }
  }'
