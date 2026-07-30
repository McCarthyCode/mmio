#!/bin/bash
# Bot-identity enforcement hook for Claude Code PreToolUse:Bash, scoped to this repo.
#
# Rewrites commands the ASSISTANT issues (never `!`-prefixed human passthrough, which
# never reaches PreToolUse at all) so agent-authored git commits, PRs, issues, and any
# comments/reviews on them carry the mmio-claude-agent[bot] GitHub App identity instead
# of the human's own. See docs/runbooks/ and AGENTS.md for why this exists.
#
# - `git commit` -> gets a one-off `-c user.name=/-c user.email=` override (never
#   touches any config file, so it can't leak into the human's own commits).
# - `gh pr <anything>` / `gh issue <anything>` -> routed through scripts/gh_app_exec.sh,
#   which mints a fresh GitHub App installation token and runs `gh` authenticated as the
#   bot (git config alone can't do this -- who "posted" something via the API is
#   determined by API auth, not commit metadata). Blanket-matched on the `pr`/`issue`
#   subcommand rather than an allowlist of specific verbs, so `close -c`, `reopen -c`,
#   `review`, `edit`, `merge`, etc. all get bot auth too, not just `create`/`comment`.
#
# Known gaps (not fixed here):
# - A global flag before the subcommand (`gh -R owner/repo pr comment ...`) won't match
#   the anchored regex below.
# - A bare `gh api` call that happens to post a comment/PR directly bypasses this
#   entirely -- only `gh pr`/`gh issue` subcommand forms are matched.
#
# Multi-line/heredoc commands are NOT silently skipped: if one still contains what
# looks like a `git commit` / `gh pr` / `gh issue` statement that this hook can't safely
# rewrite (string surgery only handles single-line commands), the call is denied with an
# explanation instead of passing through under the wrong identity.

if ! command -v jq &>/dev/null; then
  exit 0
fi

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Multi-line / heredoc commands -- the string surgery below assumes single-line, so
# these can't be safely rewritten. Rather than passing them through silently (which is
# exactly how a `gh pr create` chained after a `cat <<EOF` body-write once slipped out
# under the human's own identity), deny if one still contains what looks like a
# `git commit` / `gh pr` / `gh issue` statement -- this is a regex heuristic, not a real
# shell parser, so it's biased toward over-blocking rather than risking a silent miss.
case "$CMD" in
  *$'\n'*|*'<<'*)
    # No need to special-case embedded newlines here: grep already applies `^`/`$` to
    # each line of multi-line input by default, so this catches the statement whether
    # it's on its own line or chained after `;`/`&&`/`|` on the same line.
    if echo "$CMD" | grep -qE '(^|[;&|])[[:space:]]*(git[[:space:]]+commit([[:space:]]|$)|gh[[:space:]]+(pr|issue)([[:space:]]|$))'; then
      jq -n '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "deny",
          "permissionDecisionReason": "This command mixes a heredoc/multi-line body with a git commit / gh pr / gh issue call that BotIdentity.hook.sh cannot safely rewrite (string surgery only handles single-line commands) -- it would silently run under your own identity instead of mmio-claude-agent[bot]. Write any body text to a file first (a separate Write tool call, or a standalone heredoc-only Bash command), then reissue the git/gh call as its own plain single-line command (e.g. using --body-file / -F), so this hook can rewrite it."
        }
      }'
    fi
    exit 0
    ;;
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
    # Blanket match on the pr/issue subcommand rather than an allowlist of specific
    # verbs -- close -c, reopen -c, review, edit, merge, comment, create, etc. all get
    # routed, including verbs/flags added to gh after this was written.
    if echo "$CMD_BODY" | grep -qE '^gh[[:space:]]+(pr|issue)([[:space:]]|$)'; then
      REST="${CMD_BODY#gh}"
      REWRITTEN="${ENV_PREFIX}${GH_APP_EXEC}${REST}"
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
