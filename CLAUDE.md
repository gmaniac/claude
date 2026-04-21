# CLAUDE.md

Guidance for Claude Code when working inside this repo.

## What this repo is

A git-tracked mirror of my personal Claude Code agent roster
(`~/.claude/agents/`) and the maintenance scripts that keep it curated
(`~/.claude/scripts/`). A weekly cron job (`agent-review.sh`) edits the live
files under `~/.claude/`, then `sync-to-repo.sh` rsyncs those changes in
here and pushes `origin/main`.

## Source of truth

**The live files under `~/.claude/` are authoritative.** The copies under
`agents/` and `scripts/` in this repo are populated by `sync-to-repo.sh` and
will be overwritten on the next sync. Do not edit the repo copies directly.

When asked to change an agent or script:

1. Edit the file under `~/.claude/agents/<name>.md` or
   `~/.claude/scripts/<name>.sh`.
2. Run `~/.claude/scripts/sync-to-repo.sh` to propagate the change here and
   push, **only when the user asks for it**. Never push on your own.

## Agent file format

Each file under `agents/` has YAML frontmatter and a Markdown body:

```markdown
---
name: agent-name
description: One-to-two sentence summary. Examples belong in the body, not here.
model: opus | sonnet | haiku
tools: Read, Write, Edit, Bash, Glob, Grep    # whatever the agent actually needs
---

<instructions for the agent>
```

Rules from past feedback:

- Keep `description` to 1–2 sentences. Put usage examples in the body.
- `name` must match the filename (minus `.md`).
- Only list tools the agent actually uses.
- Pick the smallest model that does the job: haiku for lightweight,
  sonnet for standard implementation, opus for complex reasoning / critical
  review.

## Script conventions

- All scripts are plain bash, `set -u` or stricter, and log to
  `~/.claude/logs/`.
- `agent-review.sh` runs Claude non-interactively
  (`claude --dangerously-skip-permissions -p ...`). Preserve that
  invocation pattern when editing.
- `sync-to-repo.sh` is idempotent and a no-op when nothing changed.
- Any new script that needs cron scheduling should be documented in the
  README.

## What not to do here

- Don't commit or push unless the user explicitly asks. The weekly cron
  handles routine pushes; manual pushes should be deliberate.
- Don't ignore `*.log` by editing `.gitignore` — logs stay local by design.
- Don't add a CI workflow that pushes back to `main`; the sync script is
  the only writer.
- Don't rewrite history on `main`. Force-push is not appropriate here.

## Useful paths

| Path | What |
|---|---|
| `~/.claude/agents/` | Live agent files (source of truth) |
| `~/.claude/scripts/` | Live scripts (source of truth) |
| `~/.claude/logs/agent-reviews/` | Review report archive |
| `~/.claude/logs/agent-review.log` | Cron status log |
| `~/.claude/logs/sync-to-repo.log` | Sync status log |
| `~/claude-agents/` | This repo (mirror) |
