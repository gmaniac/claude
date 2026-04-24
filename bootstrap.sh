#!/usr/bin/env bash
# bootstrap.sh - Install/update ~/.claude/ from this repo on a new machine.
#
# Safe to re-run: existing files that would be overwritten are backed up
# per-file into ~/.claude.bak.<timestamp>/ preserving paths. Machine-specific
# files (.credentials.json, settings.local.json, plugin caches) are never
# in the source, so rsync without --delete leaves them alone.
#
# Usage: ./bootstrap.sh [--dry-run] [--skip-bd] [--skip-backup] [--help]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/home/.claude"
DEST="$HOME/.claude"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.claude.bak.$TIMESTAMP"

DRY_RUN=false
SKIP_BD=false
SKIP_BACKUP=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Install/update ~/.claude/ from this repo on a new machine.

Options:
  --dry-run      Show what would change; make no modifications
  --skip-bd      Don't try to install the 'bd' binary
  --skip-backup  Don't back up overwritten files (dangerous)
  --help, -h     Show this help

Steps:
  1. Check prerequisites (git, rsync)
  2. rsync $SRC/ -> $DEST/ (merge mode; overwritten files saved into
     $BACKUP_DIR)
  3. Install 'bd' binary via 'go install' if missing and go is available
  4. Print post-install checklist (auth, plugin hydration, cron)

The script never deletes files on the destination, never touches
~/.credentials.json, and never overwrites settings.local.json.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --skip-bd)     SKIP_BD=true ;;
    --skip-backup) SKIP_BACKUP=true ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

say()  { printf '\033[36m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Prereqs ---
say "Checking prerequisites..."
command -v git >/dev/null   || die "git is required"
command -v rsync >/dev/null || die "rsync is required"
[ -d "$SRC" ] || die "Source directory not found: $SRC (run from repo root)"

say "Source:      $SRC"
say "Destination: $DEST"
$DRY_RUN && say "Mode:        DRY RUN"

# --- Sync ---
RSYNC_OPTS=(-a --human-readable)
$DRY_RUN && RSYNC_OPTS+=(--dry-run --itemize-changes)

if [ -d "$DEST" ] && ! $SKIP_BACKUP; then
  RSYNC_OPTS+=(--backup --backup-dir="$BACKUP_DIR")
  say "Overwritten files will be backed up to: $BACKUP_DIR"
fi

mkdir -p "$DEST"
say "Running rsync..."
rsync "${RSYNC_OPTS[@]}" "$SRC/" "$DEST/"

# --- bd binary ---
if ! $SKIP_BD; then
  if command -v bd >/dev/null 2>&1; then
    say "bd already installed: $(bd --version 2>&1 | head -1)"
  elif command -v go >/dev/null 2>&1; then
    say "Installing 'bd' via 'go install github.com/steveyegge/beads/cmd/bd@latest'..."
    if $DRY_RUN; then
      say "(dry-run) skipped go install"
    else
      go install github.com/steveyegge/beads/cmd/bd@latest || \
        warn "bd install failed — install manually from https://github.com/steveyegge/beads"
    fi
  else
    warn "go not found and bd not installed."
    warn "Install Go (https://go.dev/dl) and rerun, or install bd manually"
    warn "from https://github.com/steveyegge/beads releases."
  fi
fi

# --- Post-install ---
cat <<'EOF'

---------------------------------------------------------------------------
 Bootstrap complete. Next steps:

 1. Launch Claude Code once to rehydrate plugin caches:
      claude
    Registered marketplaces: plugins/known_marketplaces.json
    Enabled plugins: see ~/.claude/settings.json ('enabledPlugins')

 2. Authenticate:
      - Anthropic: run 'claude' and follow login prompts
      - MCP servers: set env vars per ~/.claude/settings.json 'mcpServers'
        (e.g. TAVILY_API_KEY for the tavily server, if enabled)

 3. Verify:
      ls ~/.claude/agents/   # 30 agents expected
      ls ~/.claude/commands/ # slash commands
      bd --version           # beads CLI should work

 4. Optional: weekly agent review cron. Add to 'crontab -e':
EOF
echo "      47 2 * * 0 $HOME/.claude/scripts/agent-review.sh"
cat <<EOF

 5. If you have machine-specific settings, create:
      $HOME/.claude/settings.local.json

EOF
if [ -d "$BACKUP_DIR" ]; then
  echo " Overwritten files backed up at: $BACKUP_DIR"
else
  echo " (No backup created — fresh install or --skip-backup)"
fi
cat <<'EOF'
---------------------------------------------------------------------------
EOF
