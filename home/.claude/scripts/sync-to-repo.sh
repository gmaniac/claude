#!/bin/bash
# sync-to-repo.sh - Mirrors portable parts of ~/.claude/ into the
# gmaniac/claude repo and pushes any changes to GitHub. Machine-specific
# state (sessions, caches, credentials) is explicitly excluded.
#
# Runs at the end of agent-review.sh (weekly cron), or manually any time
# live files change. Idempotent: no-op when nothing has changed.

set -u

REPO_DIR="${CLAUDE_AGENTS_REPO:-$HOME/claude-agents}"
SRC="$HOME/.claude"
DEST="$REPO_DIR/home/.claude"
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

git checkout main >> "$LOG" 2>&1 || { log "ERROR: checkout main failed"; exit 1; }
git pull --ff-only origin main >> "$LOG" 2>&1 || log "WARN: pull failed (continuing)"

mkdir -p "$DEST"

# Top-level framework docs (*.md at ~/.claude root)
for f in "$SRC"/*.md; do
  [ -f "$f" ] && cp "$f" "$DEST/"
done

# Global settings (never settings.local.json)
[ -f "$SRC/settings.json" ] && cp "$SRC/settings.json" "$DEST/settings.json"

# Directories that mirror wholesale (source of truth is live)
for d in agents commands hooks skills scripts; do
  if [ -d "$SRC/$d" ]; then
    mkdir -p "$DEST/$d"
    rsync -a --delete "$SRC/$d/" "$DEST/$d/"
  fi
done

# Plugin config - portable parts only. Caches, marketplaces clones, and
# machine-specific install paths are excluded via .gitignore.
mkdir -p "$DEST/plugins"
[ -f "$SRC/plugins/config.json" ]             && cp "$SRC/plugins/config.json"             "$DEST/plugins/config.json"
[ -f "$SRC/plugins/known_marketplaces.json" ] && cp "$SRC/plugins/known_marketplaces.json" "$DEST/plugins/known_marketplaces.json"

# Latest agent-review report into reports/
if [ -d "$REVIEWS_DIR" ]; then
  mkdir -p "$REPO_DIR/reports"
  LATEST_REPORT=$(ls -t "$REVIEWS_DIR"/*.md 2>/dev/null | head -1)
  [ -n "$LATEST_REPORT" ] && cp "$LATEST_REPORT" "$REPO_DIR/reports/"
fi

# Safety net: refuse to commit if any staged path looks like a secret
if git status --porcelain | grep -E '(\.credentials\.json|settings\.local\.json|\.env($|\.)|\.(key|pem)$|_(rsa|ed25519)$)' > /dev/null; then
  log "ERROR: Secret-like file staged. Aborting before commit."
  git status --porcelain >> "$LOG"
  exit 2
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
