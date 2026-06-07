#!/bin/bash
# Interaction Review - runs nightly via cron, decoupled from agent-review.sh.
#
# Two distinct, separated outputs per run:
#   1) Agent-edit PROPOSALS  -> Beads issues (dedicated db) for morning review.
#      NEVER auto-applied. Each proposal = proposed diff + quoted correction
#      turn(s) as evidence + session link + recurrence count + severity.
#      Gated on recurrence (seen across N+ sessions) and de-duplicated against
#      open issues and a declined ledger / wontfix label.
#   2) Coaching DIGEST -> dated markdown file (the run's final stdout).
#      Lighter; about the user's own prompting/workflow friction only.
#
# Data tiers:
#   - Broad: claude-mem observations since last run (cheap, spans everything) ->
#     recurrence detection + coaching.
#   - Narrow: for sessions that surface a candidate agent change, pull scoped
#     transcript slices weighted to correction/redirection turns as evidence.
#     Whole transcripts are NEVER fed; only scoped slices for flagged sessions.

set -uo pipefail

# --- PATH for cron environment (mirrors agent-review.sh) ---
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node/ 2>/dev/null | tail -1)/bin:$PATH"

# --- Config (override via env) ---
RECURRENCE_MIN="${RECURRENCE_MIN:-3}"          # min distinct sessions for an agent-edit proposal
EFFORT="${EFFORT:-high}"                         # claude effort level (nightly: high to balance cost)
LOOKBACK_DEFAULT_DAYS="${LOOKBACK_DEFAULT_DAYS:-7}"  # window used on very first run
DRY_RUN="${DRY_RUN:-0}"                          # 1 = scaffold/checks only, skip the claude call

# --- Paths ---
LOG_DIR="$HOME/.claude/logs"
REVIEW_LOG="$LOG_DIR/interaction-review.log"
DIGEST_DIR="$LOG_DIR/interaction-reviews"
STATE_FILE="$HOME/.claude/.interaction-review.state"        # last successful run, epoch ms
DECLINED_LEDGER="$HOME/.claude/.interaction-review-declined.jsonl"  # optional manual skip list
HISTORY="$HOME/.claude/history.jsonl"
PROJECTS_DIR="$HOME/.claude/projects"
CLAUDE_MEM_DB="$HOME/.claude-mem/claude-mem.db"
LOCK_FILE="/tmp/interaction_review.lock"

# Dedicated beads db for the proposal queue (keeps it out of project trackers)
export BEADS_DIR="$HOME/.claude/interaction-review/.beads"
BD_PREFIX="air"

mkdir -p "$LOG_DIR" "$DIGEST_DIR" "$(dirname "$BEADS_DIR")"
touch "$DECLINED_LEDGER"

TIMESTAMP="$(date +%Y-%m-%d_%H%M)"
DIGEST="$DIGEST_DIR/coaching-$TIMESTAMP.md"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$REVIEW_LOG"; }

# --- Single-instance lock ---
if [ -f "$LOCK_FILE" ] && kill -0 "$(cat "$LOCK_FILE" 2>/dev/null)" 2>/dev/null; then
  log "Already running (PID $(cat "$LOCK_FILE")). Exiting."
  exit 0
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

cd "$HOME" || exit 1
log "=== Interaction Review start (effort=$EFFORT recurrence_min=$RECURRENCE_MIN dry_run=$DRY_RUN) ==="

# --- Tool availability ---
if ! command -v claude &>/dev/null; then
  log "ERROR: claude not found in PATH"; exit 1
fi
if ! command -v bd &>/dev/null; then
  log "ERROR: bd (beads) not found in PATH"; exit 1
fi

# --- Determine analysis window [SINCE, NOW) ---
NOW_MS="$(date +%s%3N)"
if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
  SINCE_MS="$(cat "$STATE_FILE")"
else
  SINCE_MS="$(( NOW_MS - LOOKBACK_DEFAULT_DAYS*24*3600*1000 ))"
fi
SINCE_HUMAN="$(date -d "@$((SINCE_MS/1000))" '+%Y-%m-%d %H:%M' 2>/dev/null || echo unknown)"
NOW_HUMAN="$(date '+%Y-%m-%d %H:%M')"
log "Window: $SINCE_HUMAN -> $NOW_HUMAN (since_ms=$SINCE_MS)"

# --- Cheap idle pre-check: any prompts typed since SINCE? skip the costly run if not ---
NEW_PROMPTS=0
if [ -f "$HISTORY" ]; then
  NEW_PROMPTS="$(python3 - "$HISTORY" "$SINCE_MS" <<'PY' 2>/dev/null || echo 0
import sys, json
path, since = sys.argv[1], int(sys.argv[2])
n = 0
for line in open(path, encoding="utf-8", errors="ignore"):
    try:
        ts = json.loads(line).get("timestamp", 0)
    except Exception:
        continue
    if ts and ts >= since:
        n += 1
print(n)
PY
)"
fi
log "New prompts since window start: $NEW_PROMPTS"
if [ "${NEW_PROMPTS:-0}" -eq 0 ] && [ "$DRY_RUN" != "1" ]; then
  log "No new activity. Skipping run (state unchanged)."
  exit 0
fi

# --- Ensure dedicated beads db + labels exist (idempotent) ---
if [ ! -f "$BEADS_DIR/"*.db ] 2>/dev/null && [ ! -d "$BEADS_DIR" ]; then :; fi
if ! bd list >/dev/null 2>&1; then
  log "Initializing beads db at $BEADS_DIR (prefix=$BD_PREFIX)"
  ( cd "$(dirname "$BEADS_DIR")" && bd init --prefix "$BD_PREFIX" >/dev/null 2>&1 ) \
    || bd init --prefix "$BD_PREFIX" >/dev/null 2>&1 \
    || log "WARN: bd init may have failed; check $BEADS_DIR"
fi
# Labels (agent-edit / declined / wontfix) auto-create when applied via `bd
# create -l <label>` in this bd version; no explicit label-create step needed.

if [ "$DRY_RUN" = "1" ]; then
  log "DRY_RUN: scaffolding OK. beads=$BEADS_DIR digest_would_be=$DIGEST"
  echo "DRY_RUN ok. window=$SINCE_HUMAN..$NOW_HUMAN new_prompts=$NEW_PROMPTS beads=$BEADS_DIR"
  exit 0
fi

log "Running analysis (claude -p, edits hard-blocked)..."
# The prompt lives in interaction-review.prompt.md next to this script.
PROMPT_FILE="$HOME/.claude/scripts/interaction-review.prompt.md"
if [ ! -f "$PROMPT_FILE" ]; then
  log "ERROR: prompt file missing: $PROMPT_FILE"; exit 1
fi

# Export context the prompt references.
export IR_SINCE_HUMAN="$SINCE_HUMAN" IR_NOW_HUMAN="$NOW_HUMAN" IR_SINCE_MS="$SINCE_MS"
export IR_RECURRENCE_MIN="$RECURRENCE_MIN" IR_BEADS_DIR="$BEADS_DIR" IR_BD_PREFIX="$BD_PREFIX"
export IR_HISTORY="$HISTORY" IR_PROJECTS_DIR="$PROJECTS_DIR" IR_CLAUDE_MEM_DB="$CLAUDE_MEM_DB"
export IR_DECLINED_LEDGER="$DECLINED_LEDGER"

IR_VARS='$IR_SINCE_HUMAN $IR_NOW_HUMAN $IR_SINCE_MS $IR_RECURRENCE_MIN $IR_BEADS_DIR $IR_BD_PREFIX $IR_HISTORY $IR_PROJECTS_DIR $IR_CLAUDE_MEM_DB $IR_DECLINED_LEDGER'
PROMPT_BODY="$(envsubst "$IR_VARS" < "$PROMPT_FILE")"

# Hard guarantee: Edit/Write/NotebookEdit are DISALLOWED, so agent definitions
# cannot be modified. Proposals are created only via Bash->bd. The final stdout
# (the coaching digest) is captured to $DIGEST.
# Prompt is piped via STDIN (not a positional arg): --disallowed-tools is
# variadic and would otherwise swallow a trailing prompt argument as a "tool".
printf '%s' "$PROMPT_BODY" | claude --dangerously-skip-permissions -p \
  --output-format text \
  --effort "$EFFORT" \
  --disallowed-tools Edit Write NotebookEdit \
  > "$DIGEST" 2>>"$REVIEW_LOG"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "$NOW_MS" > "$STATE_FILE"   # advance window only on success
  OPEN_PROPOSALS="$(bd list --label agent-edit --status open --json 2>/dev/null | python3 -c 'import sys,json;
try: print(len(json.load(sys.stdin)))
except Exception: print("?")' 2>/dev/null || echo '?')"
  log "Success. Coaching digest: $DIGEST | open agent-edit proposals: $OPEN_PROPOSALS"
else
  log "FAILED (exit $EXIT_CODE). State NOT advanced; window will retry next run. Partial digest: $DIGEST"
fi

log "=== Interaction Review end ==="
echo "" >> "$REVIEW_LOG"
