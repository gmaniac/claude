# claude-agents

Version-controlled mirror of my personal Claude Code agent roster plus the
weekly cron process that keeps it curated.

The files under `agents/` are the subagents Claude Code loads from
`~/.claude/agents/`. The files under `scripts/` are the maintenance scripts
invoked by cron. Every Sunday the review script runs, updates the roster
in-place, and then pushes any changes here.

## Repo layout

```
agents/    # subagent definitions (frontmatter + instructions)
scripts/   # cron-driven maintenance scripts
reports/   # weekly agent-review reports committed after each run
```

## Scripts

| Script | Purpose |
|---|---|
| `scripts/agent-review.sh` | Weekly cron job. Runs Claude in non-interactive mode to audit the roster, cross-reference [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates), apply updates, and emit a report. Calls `sync-to-repo.sh` on exit. |
| `scripts/sync-to-repo.sh` | Mirrors `~/.claude/agents/` and `~/.claude/scripts/` into this repo, copies the latest review report into `reports/`, commits, and pushes `origin/main`. No-op when nothing has changed. |
| `scripts/update-agents.sh` | Pulls the latest upstream versions of a curated agent list from `claude-code-templates`. |

## How the weekly flow works

```
Sunday 02:47  cron fires agent-review.sh
              └─ Claude audits ~/.claude/agents/, edits files in place
                 └─ writes report to ~/.claude/logs/agent-reviews/
                    └─ sync-to-repo.sh
                       ├─ rsync ~/.claude/agents/ → repo/agents/
                       ├─ rsync ~/.claude/scripts/ → repo/scripts/
                       ├─ copy latest report → repo/reports/
                       └─ git commit + git push origin main
```

## Setup on a new machine

Requires: `git`, `rsync`, [claude](https://docs.claude.com/en/docs/claude-code/overview) CLI, and an SSH key registered with the GitHub account.

```bash
# 1. Clone the repo
git clone git@github.com:gmaniac/claude-agents.git ~/claude-agents

# 2. Install the live copies into ~/.claude/
mkdir -p ~/.claude/agents ~/.claude/scripts
rsync -a ~/claude-agents/agents/  ~/.claude/agents/
rsync -a ~/claude-agents/scripts/ ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh

# 3. Verify the SSH remote works
ssh -T git@github.com

# 4. Install the weekly cron entry
( crontab -l 2>/dev/null; echo '47 2 * * 0 /home/'"$USER"'/.claude/scripts/agent-review.sh' ) | crontab -
```

Override the repo location by exporting `CLAUDE_AGENTS_REPO` before running
the sync script, e.g. `CLAUDE_AGENTS_REPO=/opt/claude-agents`.

## Manual operations

```bash
# Force a sync without waiting for Sunday
~/.claude/scripts/sync-to-repo.sh

# Run the full review+sync right now
~/.claude/scripts/agent-review.sh

# Update upstream-sourced agents only (no review, no sync)
~/.claude/scripts/update-agents.sh
```

## Source of truth

`~/.claude/agents/` and `~/.claude/scripts/` are the live files Claude Code
actually reads. This repo is a git-tracked mirror populated by
`sync-to-repo.sh`. When editing, prefer editing the live files under
`~/.claude/` — the next sync will propagate your changes here. Editing the
repo copies directly will be overwritten on the next run.

## Logs (not committed)

Runtime logs stay local and are gitignored:

- `~/.claude/logs/agent-review.log` — per-run status
- `~/.claude/logs/sync-to-repo.log` — rsync / commit / push detail
- `~/.claude/logs/agent-reviews/*.md` — full Claude review transcripts (the
  most recent is copied into `reports/` on each sync)
