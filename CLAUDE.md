# CLAUDE.md

Guidance for Claude Code when working inside this repo.

## What this repo is

A git-tracked mirror of my portable Claude Code configuration: agents,
slash commands, hooks, skills, framework docs, maintenance scripts, and
the plugin metadata needed to rehydrate the setup on a new machine.

A weekly cron (`agent-review.sh`) edits the live files under `~/.claude/`,
then `sync-to-repo.sh` rsyncs the portable parts into `home/.claude/` here
and pushes `origin/main`.

## Source of truth

**The live files under `~/.claude/` are authoritative.** The copies under
`home/.claude/` in this repo are populated by `sync-to-repo.sh` and will be
overwritten on the next sync. Do not edit repo copies directly.

When asked to change an agent, script, command, etc.:

1. Edit the file under `~/.claude/<path>` (e.g. `~/.claude/agents/<name>.md`).
2. Run `~/.claude/scripts/sync-to-repo.sh` to propagate and push, **only
   when the user asks for it**. Never push on your own.

## Layout

```
claude-agents/               (local clone of git@github.com:gmaniac/claude.git)
├── home/.claude/            mirror of synced ~/.claude/ paths
│   ├── *.md                 framework docs (CLAUDE, RULES, MCP, etc.)
│   ├── agents/
│   ├── commands/
│   ├── hooks/
│   ├── scripts/
│   ├── skills/
│   ├── settings.json
│   └── plugins/
│       ├── config.json
│       └── known_marketplaces.json
├── reports/                 weekly agent-review outputs
├── bootstrap.sh             (TODO) new-machine setup
├── .gitignore
└── CLAUDE.md
```

## What's synced vs excluded

**Synced** (portable):
- Framework `.md` files at `~/.claude/` root
- `agents/`, `commands/`, `hooks/`, `skills/`, `scripts/`
- `settings.json` (global only)
- `plugins/config.json`, `plugins/known_marketplaces.json`

**Excluded** (via `.gitignore`):
- `.credentials.json`, `settings.local.json`, `.env*`, `*.key`, `*.pem`
- `projects/`, `sessions/`, `history.jsonl` — session transcripts
- `cache/`, `debug/`, `file-history/`, `logs/`, etc. — ephemeral state
- `plugins/cache/`, `plugins/data/`, `plugins/marketplaces/` — auto-refetched
- `plugins/installed_plugins.json` — machine-specific install paths

## Agent file format

YAML frontmatter + Markdown body:

```markdown
---
name: agent-name
description: One-to-two sentence summary. Examples belong in the body, not here.
model: opus | sonnet | haiku
tools: Read, Write, Edit, Bash, Glob, Grep    # what the agent actually needs
---

<instructions for the agent>
```

Rules (from past feedback):
- Keep `description` to 1-2 sentences. Put usage examples in the body.
- `name` must match the filename (minus `.md`).
- Only list tools the agent actually uses.
- Smallest model that does the job: haiku lightweight, sonnet standard,
  opus complex reasoning / critical review.

## Script conventions

- Plain bash, `set -u` or stricter, log to `~/.claude/logs/`.
- `agent-review.sh` runs Claude non-interactively
  (`claude --dangerously-skip-permissions -p ...`). Preserve that pattern.
- `sync-to-repo.sh` is idempotent and no-ops when nothing changed. It also
  refuses to commit if a secret-like path appears staged.
- New scripts that need cron scheduling should be documented in the README.

## What not to do here

- Don't commit or push unless the user explicitly asks.
- Don't rewrite history on `main`. No force-push.
- Don't add a CI workflow that writes back to `main` — `sync-to-repo.sh`
  is the only authorized writer.
- Don't expand sync scope without auditing new paths for secrets.

## Useful paths

| Path | What |
|---|---|
| `~/.claude/` | Live config (source of truth) |
| `~/.claude/logs/agent-reviews/` | Weekly review archive |
| `~/.claude/logs/agent-review.log` | Cron status log |
| `~/.claude/logs/sync-to-repo.log` | Sync status log |
| `~/claude-agents/` | This repo (local clone) |
| `git@github.com:gmaniac/claude.git` | Remote |
