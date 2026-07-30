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
# The matching below is regex/string-surgery, not a real shell parser. It checks each
# top-level `&&`-separated segment of the command independently (so `git checkout -b x
# && git commit ...` rewrites the second segment), and embedded heredocs/newlines
# within a single segment's own arguments no longer cause a blanket bypass (so `gh pr
# create --body "$(cat <<'EOF' ... EOF)"` still gets routed through gh_app_exec.sh,
# since `grep`'s `^`/`$` apply per line by default and the segment's *first* line is
# still the invocation).
#
# But if a segment hides a `git commit`/`gh pr`/`gh issue` statement that ISN'T at the
# start of the segment -- i.e. a separate statement joined by a bare newline rather
# than `&&`, such as a heredoc body-write followed by its own `gh pr create` line --
# this hook can't safely reach it by string surgery (the segment starts with `cat`, not
# the invocation). Rather than silently letting that slip through under the wrong
# identity (exactly how PR #29 opened under the human's account: a `cat > file <<EOF
# ... EOF` chained via a bare newline in front of `gh pr create` in one Bash call), the
# hook denies the call instead, with an explanation.
#
# Known gaps, same spirit as the original:
#   - only `&&`-chained commands are split; `;`- or `|`-chained commands aren't (a
#     mutating statement after a bare `;` or `|` is only caught by the trailing
#     safety-net deny below if it also contains a newline/heredoc -- a plain
#     single-line `cd x; git commit -m y` still silently passes through unrewritten).
#   - the `&&` split is naive: a literal `&&` inside a quoted argument (e.g. a commit
#     message or PR body containing the text "&&") would be mis-split. Prefer
#     `--body-file` over inline `--body`/heredoc text for exactly this reason.
#   - a bare `gh api` call that happens to post a comment isn't covered -- only the
#     `gh pr`/`gh issue` subcommand forms are matched.
#   - a global flag before the subcommand (`gh -R owner/repo pr comment ...`) won't
#     match the anchored regex.

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
# and env-var assignments) a `git commit` or `gh pr`/`gh issue` invocation. Echoes the
# segment unchanged if no rewrite applies.
rewrite_segment() {
  local seg="$1" lead body env_prefix rest first_line

  lead=$(echo "$seg" | grep -oE '^[[:space:]]*' || echo "")
  body="${seg:${#lead}}"

  # Only the segment's own FIRST line is eligible to anchor a rewrite -- `grep -q`
  # without `-z` matches `^`/`$` against every line of a multi-line string, but the
  # `${body#literal}`/`${body:n}` prefix-stripping below only makes sense if the
  # match is truly at the start of `body`. Checking the whole (possibly multi-line)
  # `body` against `^gh[[:space:]]+(pr|issue)` would happily match a `gh pr create`
  # that only appears on a LATER line (e.g. after a heredoc body-write) and then
  # silently mis-strip, producing a corrupted command instead of a safe rewrite --
  # confirmed while testing this merge. That shape is exactly what the trailing
  # UNREACHABLE safety net further down is for, so it must fall through to that,
  # not get "rewritten" here.
  first_line="${body%%$'\n'*}"

  env_prefix=$(echo "$first_line" | grep -oE '^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)+' || echo "")
  if [ -n "$env_prefix" ]; then
    body="${body:${#env_prefix}}"
    first_line="${first_line:${#env_prefix}}"
  fi

  if echo "$first_line" | grep -qE '^git[[:space:]]+commit([[:space:]]|$)'; then
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
    # Blanket match on the pr/issue subcommand rather than an allowlist of specific
    # verbs -- close -c, reopen -c, review, edit, merge, comment, create, etc. all get
    # routed, including verbs/flags added to gh after this was written.
    if echo "$first_line" | grep -qE '^gh[[:space:]]+(pr|issue)([[:space:]]|$)'; then
      rest="${body#gh}"
      echo "${lead}${env_prefix}${GH_APP_EXEC}${rest}"
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
UNREACHABLE=0
REWRITTEN=""
for i in "${!SEGMENTS[@]}"; do
  SEG="${SEGMENTS[$i]}"
  NEW_SEG=$(rewrite_segment "$SEG")
  if [ "$NEW_SEG" != "$SEG" ]; then
    CHANGED=1
  else
    # Untouched segment -- if it still hides a mutating statement behind a heredoc/
    # embedded newline (not reachable by rewrite_segment's start-anchored match),
    # flag it rather than let it pass silently. grep applies `^`/`$` per line by
    # default, so this catches the statement whether it's on its own line or chained
    # after `;`/`&`/`|` on the same line.
    case "$SEG" in
      *$'\n'*|*'<<'*)
        if echo "$SEG" | grep -qE '(^|[;&|])[[:space:]]*(git[[:space:]]+commit([[:space:]]|$)|gh[[:space:]]+(pr|issue)([[:space:]]|$))'; then
          UNREACHABLE=1
        fi
        ;;
    esac
  fi
  if [ "$i" -eq 0 ]; then
    REWRITTEN="$NEW_SEG"
  else
    REWRITTEN="${REWRITTEN}&&${NEW_SEG}"
  fi
done

if [ "$UNREACHABLE" -eq 1 ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "This command hides a git commit / gh pr / gh issue statement behind a heredoc or bare newline (not at the start of its && segment) that BotIdentity.hook.sh cannot safely reach by string surgery -- it would silently run under your own identity instead of mmio-claude-agent[bot]. Write any body text to a file first (a separate Write tool call, or a standalone heredoc-only Bash command), then reissue the git/gh call as its own plain single-line command (e.g. using --body-file / -F), so this hook can rewrite it."
    }
  }'
  exit 0
fi

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
