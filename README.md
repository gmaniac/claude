# claude

Version-controlled mirror of my portable Claude Code configuration: agents,
slash commands, hooks, skills, framework docs, maintenance scripts, and the
plugin metadata needed to rehydrate the setup on a new machine.

A weekly cron runs `agent-review.sh`, which audits the agent roster in
place, then calls `sync-to-repo.sh` to rsync the portable parts into this
repo and push `origin/main`.

## Repo layout

```
home/.claude/            mirror of synced ~/.claude/ paths
├── *.md                 framework docs (CLAUDE, RULES, MCP, PERSONAS, etc.)
├── agents/              30 subagent definitions
├── commands/            custom slash commands
├── hooks/               dangerous-command-blocker, secret-scanner
├── scripts/             cron scripts (agent-review, sync-to-repo, update-agents)
├── skills/              user-invokable skills (brainstorming, claude-api, ...)
├── settings.json        global Claude Code config
└── plugins/
    ├── config.json
    └── known_marketplaces.json
reports/                 latest weekly agent-review output
bootstrap.sh             new-machine installer
CLAUDE.md                repo-level guidance for Claude Code
```

## What's synced vs excluded

Synced (portable):
- Framework `.md` files at `~/.claude/` root
- `agents/`, `commands/`, `hooks/`, `skills/`, `scripts/`
- `settings.json` (global only)
- `plugins/config.json` + `plugins/known_marketplaces.json`

Excluded (via `.gitignore`):
- `.credentials.json`, `settings.local.json`, `.env*`, `*.key`, `*.pem`
- `projects/`, `sessions/`, `history.jsonl` — session transcripts
- `cache/`, `debug/`, `logs/`, `file-history/`, `backups/`, etc.
- `plugins/cache/`, `plugins/data/`, `plugins/marketplaces/` (auto-refetched)
- `plugins/installed_plugins.json` (machine-specific install paths)

## Setup on a new machine

Requires: `git`, `rsync`, Claude Code CLI, SSH key registered on GitHub.
Optional: `go` (for `bd` binary install).

```bash
# 1. Clone
git clone git@github.com:gmaniac/claude.git ~/claude-config

# 2. Preview what would happen
~/claude-config/bootstrap.sh --dry-run

# 3. Install (merges into ~/.claude/, backs up overwrites)
~/claude-config/bootstrap.sh

# 4. Launch Claude once to rehydrate plugin caches + auth
claude

# 5. (Optional) install weekly agent-review cron
( crontab -l 2>/dev/null; echo "47 2 * * 0 $HOME/.claude/scripts/agent-review.sh" ) | crontab -
```

`bootstrap.sh` never deletes files on the destination, preserves any
existing `.credentials.json` / `settings.local.json`, and stashes
overwritten files into `~/.claude.bak.<timestamp>/`.

See `./bootstrap.sh --help` for options (`--dry-run`, `--skip-bd`,
`--skip-backup`).

## How the weekly flow works

```
Sunday 02:47  cron fires agent-review.sh
              └─ Claude audits ~/.claude/agents/, edits in place
                 └─ writes report to ~/.claude/logs/agent-reviews/
                    └─ sync-to-repo.sh
                       ├─ rsync portable ~/.claude/ paths → repo/home/.claude/
                       ├─ copy latest report → repo/reports/
                       ├─ abort if any secret-like file is staged
                       └─ git commit + push origin main
```

## Cross-machine workflow

This repo has a **single writer** — the primary machine with the cron.
Secondary machines should pull, not push:

```bash
# On a secondary machine, before starting work
cd ~/claude-config && git pull --ff-only
~/claude-config/bootstrap.sh   # applies any new upstream changes
```

If a secondary machine needs to make permanent changes (new agent, edited
command), edit under `~/.claude/` as usual, then either:
- copy the edit to the primary machine for the next cron run, or
- on the secondary, commit + push this repo manually (risks conflict with
  the next cron push from primary — pull first).

Source of truth is always `~/.claude/` on the primary machine.

## Manual operations

```bash
# Force a sync without waiting for Sunday
~/.claude/scripts/sync-to-repo.sh

# Run the full review + sync right now
~/.claude/scripts/agent-review.sh

# Update upstream-sourced agents only (no review, no sync)
~/.claude/scripts/update-agents.sh
```

Override the local repo path by exporting `CLAUDE_AGENTS_REPO` before
running the sync script, e.g. `CLAUDE_AGENTS_REPO=/opt/claude`.

## Source of truth

`~/.claude/` is authoritative. The repo is a mirror populated by
`sync-to-repo.sh`. When editing, change the live files — the next sync
propagates them here. Edits made directly to repo files will be
overwritten on the next run.

## Logs (not committed)

- `~/.claude/logs/agent-review.log` — per-run cron status
- `~/.claude/logs/sync-to-repo.log` — rsync / commit / push detail
- `~/.claude/logs/agent-reviews/*.md` — full Claude review transcripts
  (the most recent is copied into `reports/` on each sync)
