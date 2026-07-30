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
# The matching below is regex/string-surgery, not a real shell parser. It checks each
# top-level `&&`-separated segment of the command (so `git checkout -b x && git commit
# ...` rewrites the second segment) and no longer skips multi-line/heredoc commands (so
# a heredoc `gh pr create --body "$(cat <<'EOF' ... EOF)"` still gets routed through
# gh_app_exec.sh). It still has known gaps, same spirit as the original:
#   - only `&&`-chained commands are split; `;`- or `|`-chained commands aren't.
#   - the split is naive: a literal `&&` inside a quoted argument (e.g. a commit
#     message or PR body containing the text "&&") would be mis-split. Prefer
#     `--body-file` over inline `--body`/heredoc text for exactly this reason.
#   - a bare `gh api` call that happens to post a comment isn't covered -- only the
#     `gh pr comment` / `gh issue comment` subcommand forms are matched.

if ! command -v jq &>/dev/null; then
  exit 0
fi

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

BOT_NAME="mmio-claude-agent[bot]"
BOT_EMAIL="308820401+mmio-claude-agent[bot]@users.noreply.github.com"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
GH_APP_EXEC="${REPO_ROOT}/scripts/gh_app_exec.sh"

# Rewrites a single `&&`-segment in place if it's (after stripping leading whitespace
# and env-var assignments) a `git commit`/`gh pr create`/`gh pr comment`/`gh issue
# comment` invocation. Echoes the segment unchanged if no rewrite applies.
rewrite_segment() {
  local seg="$1" lead body env_prefix rest

  lead=$(echo "$seg" | grep -oE '^[[:space:]]*' || echo "")
  body="${seg:${#lead}}"

  env_prefix=$(echo "$body" | grep -oE '^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)+' || echo "")
  if [ -n "$env_prefix" ]; then
    body="${body:${#env_prefix}}"
  fi

  if echo "$body" | grep -qE '^git[[:space:]]+commit([[:space:]]|$)'; then
    # Idempotent: already rewritten (or manually bot-authored) -- leave alone.
    if echo "$body" | grep -qF "$BOT_EMAIL"; then
      echo "$seg"
      return
    fi
    rest="${body#git}"
    echo "${lead}${env_prefix}git -c user.name=\"${BOT_NAME}\" -c user.email=\"${BOT_EMAIL}\"${rest}"
    return
  fi

  if [ -n "$REPO_ROOT" ] && [ -x "$GH_APP_EXEC" ]; then
    if echo "$body" | grep -qE '^gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
      rest="${body#gh pr create}"
      echo "${lead}${env_prefix}${GH_APP_EXEC} pr create${rest}"
      return
    elif echo "$body" | grep -qE '^gh[[:space:]]+pr[[:space:]]+comment([[:space:]]|$)'; then
      rest="${body#gh pr comment}"
      echo "${lead}${env_prefix}${GH_APP_EXEC} pr comment${rest}"
      return
    elif echo "$body" | grep -qE '^gh[[:space:]]+issue[[:space:]]+comment([[:space:]]|$)'; then
      rest="${body#gh issue comment}"
      echo "${lead}${env_prefix}${GH_APP_EXEC} issue comment${rest}"
      return
    fi
  fi

  echo "$seg"
}

# Split CMD on top-level `&&` (naive -- see header comment on quoted-`&&` limitation).
SEGMENTS=()
REMAINDER="$CMD"
while [[ "$REMAINDER" == *"&&"* ]]; do
  SEGMENTS+=("${REMAINDER%%&&*}")
  REMAINDER="${REMAINDER#*&&}"
done
SEGMENTS+=("$REMAINDER")

CHANGED=0
REWRITTEN=""
for i in "${!SEGMENTS[@]}"; do
  NEW_SEG=$(rewrite_segment "${SEGMENTS[$i]}")
  if [ "$NEW_SEG" != "${SEGMENTS[$i]}" ]; then
    CHANGED=1
  fi
  if [ "$i" -eq 0 ]; then
    REWRITTEN="$NEW_SEG"
  else
    REWRITTEN="${REWRITTEN}&&${NEW_SEG}"
  fi
done

if [ "$CHANGED" -eq 0 ]; then
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
