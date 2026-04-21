#!/bin/bash
# sync-to-repo.sh - Mirrors live ~/.claude/{agents,scripts} into the
# claude-agents git repo and pushes any changes to GitHub.
#
# Intended to run at the end of agent-review.sh (weekly cron), but can
# also be invoked manually any time the live files have changed.

set -u

REPO_DIR="${CLAUDE_AGENTS_REPO:-$HOME/claude-agents}"
SRC_AGENTS="$HOME/.claude/agents"
SRC_SCRIPTS="$HOME/.claude/scripts"
REVIEWS_DIR="$HOME/.claude/logs/agent-reviews"
LOG="$HOME/.claude/logs/sync-to-repo.log"

mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

log "=== sync start ==="

if [ ! -d "$REPO_DIR/.git" ]; then
  log "ERROR: $REPO_DIR is not a git repo. Aborting."
  exit 1
fi

cd "$REPO_DIR" || { log "ERROR: cd $REPO_DIR failed"; exit 1; }

# Make sure we're on main and up to date before making changes
git checkout main >> "$LOG" 2>&1 || { log "ERROR: checkout main failed"; exit 1; }
git pull --ff-only origin main >> "$LOG" 2>&1 || log "WARN: pull failed (continuing)"

# Mirror agents and scripts (--delete so removals propagate)
rsync -a --delete "$SRC_AGENTS/" "$REPO_DIR/agents/"
rsync -a --delete "$SRC_SCRIPTS/" "$REPO_DIR/scripts/"

# Copy the latest review report (if any) into reports/
if [ -d "$REVIEWS_DIR" ]; then
  mkdir -p "$REPO_DIR/reports"
  LATEST_REPORT=$(ls -t "$REVIEWS_DIR"/*.md 2>/dev/null | head -1)
  if [ -n "$LATEST_REPORT" ]; then
    cp "$LATEST_REPORT" "$REPO_DIR/reports/"
  fi
fi

if [ -z "$(git status --porcelain)" ]; then
  log "No changes to commit."
  log "=== sync done (no-op) ==="
  exit 0
fi

git add -A
git commit -m "Weekly sync: $(date '+%Y-%m-%d')" >> "$LOG" 2>&1 \
  || { log "ERROR: commit failed"; exit 1; }

if git push origin main >> "$LOG" 2>&1; then
  log "Pushed to origin/main."
else
  log "ERROR: push failed. Commit is local only."
  exit 1
fi

log "=== sync done ==="
