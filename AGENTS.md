# Project-specific rules — mmio

## Runbooks

- Every AI-generated PR merged to `main` that produces a runbook must place it at
  `docs/runbooks/[PR #].md` (the number of the PR the runbook documents), not at the
  project root.

## Git identity for agent-authored work

- **Never set `user.name`/`user.email` in this repo's local git config.** It must stay
  unset so it falls back to the human's own global identity by default — that's the
  correct default for anything he commits manually. Setting it repo-locally pins *every*
  commit (including his own) to whichever identity is configured.
- Agent-authored commits and PRs are meant to carry the `mmio-claude-agent[bot]`
  GitHub App identity instead. This is enforced by `.claude/hooks/BotIdentity.hook.sh`
  (a `PreToolUse`/`Bash` hook registered in `.claude/settings.json`), which rewrites
  `git commit`, `gh pr create`, `gh pr comment`, and `gh issue comment` commands the
  assistant issues — it cannot see or rewrite commands the human runs himself
  (`!`-prefixed shell passthrough bypasses the tool-call pipeline entirely, so it never
  reaches this hook).
- Full mechanism, setup, and the token-minting/PR-wrapper scripts it depends on:
  `docs/runbooks/` (see the runbook for the PR that introduced this hook).
