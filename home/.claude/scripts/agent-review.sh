#!/bin/bash
# Weekly Claude setup audit - runs Sundays via cron.
# Phase 1: deterministic lint (no LLM) - existence/consistency checks that
#          cannot hallucinate "OK".
# Phase 2: adversarial LLM audit of the full setup surface (agents, plugins,
#          skills, commands, settings, hooks, rules, loops).
# Phase 3: notify the user and sync the repo.
#
# Rewritten 2026-07-06 after the old agent-only checklist review missed:
# orchestrators lacking the Agent tool, broken hook paths in settings.local.json,
# phantom agent rosters in rules/ecc, a dead plugin entry, and duplicate
# skills/commands. See ~/.claude/logs/agent-reviews/ for reports.

export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node/ 2>/dev/null | tail -1)/bin:$PATH"

LOG_DIR="$HOME/.claude/logs"
REVIEW_LOG="$LOG_DIR/agent-review.log"
REPORT_DIR="$LOG_DIR/agent-reviews"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H%M)
REPORT="$REPORT_DIR/review-$TIMESTAMP.md"
LINT_REPORT="$REPORT_DIR/lint-$TIMESTAMP.md"

cleanup() { rm -rf /tmp/cct-review; }
trap cleanup EXIT

log() { echo "$(date '+%H:%M:%S') $*" >> "$REVIEW_LOG"; }
echo "=== Setup Audit: $(date) ===" >> "$REVIEW_LOG"

notify() {  # best-effort desktop notification from cron
  local urgency="$1"; shift
  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" DISPLAY="${DISPLAY:-:0}"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$urgency" "Claude Setup Audit" "$*" 2>/dev/null || true
  else  # gdbus ships with glib; verified working on this machine 2026-07-06
    gdbus call --session --dest org.freedesktop.Notifications \
      --object-path /org/freedesktop/Notifications \
      --method org.freedesktop.Notifications.Notify \
      "claude-setup-audit" 0 "" "Claude Setup Audit" "$*" "[]" "{}" 10000 >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# Phase 1: deterministic lint
# ---------------------------------------------------------------------------
python3 - "$LINT_REPORT" <<'PYLINT'
import json, os, re, shutil, sys
from pathlib import Path

HOME = Path.home()
CLAUDE = HOME / ".claude"
issues, notes = [], []

def issue(msg): issues.append(msg)

# --- JSON validity + hook script paths ---
for name in ("settings.json", "settings.local.json"):
    p = CLAUDE / name
    if not p.exists():
        continue
    try:
        cfg = json.loads(p.read_text())
    except Exception as e:
        issue(f"{name}: INVALID JSON ({e})")
        continue
    for event, entries in (cfg.get("hooks") or {}).items():
        for entry in entries:
            for h in entry.get("hooks", []):
                cmd = h.get("command", "")
                if "$CLAUDE_PROJECT_DIR" in cmd:
                    issue(f"{name}: hook uses $CLAUDE_PROJECT_DIR (user-scope "
                          f"hooks break outside ~/): {cmd[:90]}")
                for m in re.findall(r'(?:\$HOME|~|/home/\w+)(/[\w./-]+\.(?:py|sh|js|cjs))', cmd):
                    path = HOME / m.lstrip("/")
                    if not path.exists():
                        issue(f"{name}: hook references missing script {path}")

# --- plugins: install paths + marketplace consistency ---
try:
    plugins = json.loads((CLAUDE / "plugins/installed_plugins.json").read_text())["plugins"]
    for pname, installs in plugins.items():
        for inst in installs:
            if not Path(inst["installPath"]).exists():
                issue(f"plugin {pname}: installPath missing ({inst['installPath']}) - dead entry")
except Exception as e:
    issue(f"installed_plugins.json unreadable: {e}")
try:
    known = json.loads((CLAUDE / "plugins/known_marketplaces.json").read_text())
    known_names = set(known.get("marketplaces", known).keys())
    disk = {d.name for d in (CLAUDE / "plugins/marketplaces").iterdir() if d.is_dir()}
    for orphan in disk - known_names:
        issue(f"marketplace dir on disk but not registered: '{orphan}'")
    for ghost in known_names - disk:
        notes.append(f"marketplace registered but no dir yet (ok if never fetched): {ghost}")
except Exception as e:
    issue(f"marketplace check failed: {e}")

# --- agents: frontmatter, models, orchestrator Agent tool ---
VALID_MODELS = {"fable", "opus", "sonnet", "haiku"}
ORCHESTRATORS = {"multi-agent-coordinator", "task-distributor", "workflow-orchestrator"}
agent_names = set()
for f in sorted((CLAUDE / "agents").glob("*.md")):
    text = f.read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        issue(f"agents/{f.name}: no frontmatter"); continue
    fm = m.group(1)
    def field(k):
        fm_m = re.search(rf"^{k}:\s*(.+)$", fm, re.M)
        return fm_m.group(1).strip().strip('"') if fm_m else None
    name, model, tools = field("name"), field("model"), field("tools")
    agent_names.add(name or f.stem)
    if name != f.stem:
        issue(f"agents/{f.name}: name '{name}' != filename")
    if not field("description"):
        issue(f"agents/{f.name}: missing description")
    if model not in VALID_MODELS:
        issue(f"agents/{f.name}: invalid model '{model}'")
    if not tools:
        issue(f"agents/{f.name}: missing tools list")
    elif f.stem in ORCHESTRATORS and "Agent" not in [t.strip() for t in tools.split(",")]:
        issue(f"agents/{f.name}: orchestrator missing the Agent tool - cannot spawn subagents")

# --- router roster sync (both directions) ---
router = (CLAUDE / "AGENT_ROUTER.md").read_text()
table_agents = set(re.findall(r"^\| ([a-z][a-z0-9-]+) \|", router, re.M))
for a in table_agents - agent_names:
    issue(f"AGENT_ROUTER.md lists '{a}' but agents/{a}.md does not exist")
for a in agent_names - table_agents:
    issue(f"agents/{a}.md exists but is missing from the AGENT_ROUTER.md roster")

# --- dead references (retired tools, removed agents/files) ---
DEAD = ["MultiEdit", "TodoRead", "context-manager", "tdd-guide",
        "build-error-resolver", "e2e-runner", "refactor-cleaner", "doc-updater",
        "harmonyos-app-resolver", "security-reviewer", "ORCHESTRATOR.md",
        "ralph-wiggum", "Serena MCP", "/sc:pm",
        # SuperClaude retired 2026-07-06 (only sc:git kept); archived commands:
        "sc:spawn", "sc:task", "sc:analyze", "sc:implement", "sc:cleanup",
        "sc:improve", "sc:explain", "sc:document", "sc:index", "sc:load",
        "sc:troubleshoot", "sc:estimate", "sc:design", "sc:build", "sc:test",
        "deep-analysis", "wave-enabled"]
SCAN = ["agents", "rules", "commands", "skills", "AGENT_ROUTER.md", "RULES.md", "CLAUDE.md"]
SKIP_PARTS = {"backups", "gstack", "node_modules", ".git"}
LEGACY_MAP_FILE = CLAUDE / "rules/ecc/common/agents.md"  # intentional legacy-name table
for target in SCAN:
    root = CLAUDE / target
    files = [root] if root.is_file() else list(root.rglob("*.md")) if root.is_dir() else []
    for f in files:
        if set(f.parts) & SKIP_PARTS or f == LEGACY_MAP_FILE or not f.is_file():
            continue  # is_file() is False for dangling symlinks - reported separately
        try:
            text = f.read_text(errors="ignore")
        except OSError:
            issue(f"{f.relative_to(CLAUDE)}: unreadable file")
            continue
        for dead in DEAD:
            if re.search(rf"(?<![\w-]){re.escape(dead)}(?![\w-])", text):
                issue(f"{f.relative_to(CLAUDE)}: dead reference '{dead}'")

# --- dangling symlinks in commands/ ---
for f in (CLAUDE / "commands").rglob("*"):
    if f.is_symlink() and not f.exists():
        issue(f"commands/{f.name}: dangling symlink -> {os.readlink(f)}")

# --- skills structure ---
for d in (CLAUDE / "skills").iterdir():
    if d.is_dir() and d.name != "gstack" and not (d / "SKILL.md").exists():
        issue(f"skills/{d.name}/: missing SKILL.md")

# --- binaries + local patches ---
for binary in ("claude", "bd", "ralph"):
    if not shutil.which(binary):
        issue(f"binary '{binary}' not on PATH")
ralph_loop = HOME / ".ralph/ralph_loop.sh"
if ralph_loop.exists() and "MAX_TOTAL_LOOPS" not in ralph_loop.read_text():
    issue("~/.ralph/ralph_loop.sh: safety caps (MAX_TOTAL_LOOPS) missing - "
          "upstream update likely wiped the 2026-07-06 patch; reapply")

# --- write lint report ---
out = ["# Lint Report (deterministic phase)", ""]
out.append(f"**Issues: {len(issues)}**")
out += [f"- [ISSUE] {i}" for i in issues]
out += [f"- [note] {n}" for n in notes]
Path(sys.argv[1]).write_text("\n".join(out) + "\n")
PYLINT
LINT_ISSUES=$(grep -c '^\- \[ISSUE\]' "$LINT_REPORT" 2>/dev/null)  # grep -c prints 0 itself on no-match
LINT_ISSUES=${LINT_ISSUES:-?}
log "Lint phase complete: $LINT_ISSUES issue(s). $LINT_REPORT"

# ---------------------------------------------------------------------------
# Phase 2: adversarial LLM audit (with model fallback)
# ---------------------------------------------------------------------------
run_llm() {
  local model_flag=()
  [ -n "$1" ] && model_flag=(--model "$1")
  claude --dangerously-skip-permissions -p --output-format text --effort max \
    "${model_flag[@]}" \
    "$(cat "$LINT_REPORT")

$(cat <<'PROMPT'
You are performing the weekly ADVERSARIAL setup audit of ~/.claude. Above is the
deterministic lint report - treat every [ISSUE] as confirmed and fix the safe ones.
Your job is to hunt for what is BROKEN, DEAD, DUPLICATED, or WASTEFUL. Do not
grade against a checklist and report "OK"; assume something is wrong and try to
find it. A finding of "no issues" requires evidence of the hunt.

## Surfaces to audit (all of them)
1. **Agents** (~/.claude/agents/): For each agent, can it EXECUTE what its body
   instructs given its `tools:` whitelist? (e.g. a body that says "spawn
   subagents" requires the Agent tool.) Does every agent/skill/command/MCP the
   body references actually exist? Least privilege: reviewers/mentors/analysts
   should not hold Write/Edit/Bash they don't need. Overlapping agents must be
   meaningfully differentiated. NEVER downgrade a `model: fable` pin. Do NOT
   add "Tool Awareness" padding - prefer trimming bloat over adding text.
2. **Plugins** (~/.claude/plugins/): dead entries, stale versions vs their
   marketplaces, hooks with per-tool-call or per-session cost that grew since
   last week, plugins for tools/terminals not actually used.
3. **Skills & commands** (~/.claude/skills/, commands/, plugin skills): duplicate
   clusters (2+ entries doing the same job), descriptions that over- or
   under-trigger, references to nonexistent skills/agents/tools. gstack lives in
   skills/gstack (a git clone) - audit its presence, not its internals.
4. **Settings & hooks** (settings.json, settings.local.json, hooks/): every hook
   command must resolve on this machine in ANY project directory; flag risky
   flags and permission changes since last week.
5. **Rules layer** (CLAUDE.md, AGENT_ROUTER.md, RULES.md, rules/ecc/): dead
   references, contradictions between files, stale model-family guidance,
   claims that don't match reality (verify, don't trust).
6. **Loops**: AGENT_ROUTER.md loop rules must stay notification-first (no
   polling of harness-tracked agents). Verify ~/.ralph/ralph_loop.sh still has
   MAX_TOTAL_LOOPS/MAX_WALL_HOURS caps and beads-in-ralph launchers still
   disable claude-mem in ralph workdirs.
7. **Upstream drift** (optional, time-permitting): shallow-clone
   https://github.com/davila7/claude-code-templates.git to /tmp/cct-review and
   note materially improved upstream agents. Skip on any network failure.

## Actions
- APPLY directly (Edit/Write) only SAFE mechanical fixes: dead references,
  broken paths, frontmatter errors, roster sync. Verify each by re-reading.
- Do NOT delete, archive, uninstall, or restructure anything - list those as
  recommendations for the user instead.
- Be conservative with additions; the setup is intentionally being slimmed.

## Report (write to STDOUT, exactly this structure)
# Setup Audit Report - [DATE]
## Summary
- Lint issues confirmed/fixed: n/n
- New findings: n (critical: n)
- Safe fixes applied: n
- Recommendations requiring user decision: n
## Findings
### [surface]: [one-line finding]
- Evidence: [file:line or command output]
- Action: [fixed - what was changed | recommendation - what user should decide]
(repeat per finding, most severe first)
## Hunt Log
- [each surface: what you checked and how, 1 line each - proves coverage]
## Recommendations
- [numbered, actionable]
PROMPT
)"
}

run_llm "" > "$REPORT" 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  log "Primary model failed (exit $EXIT_CODE) - retrying with opus fallback"
  run_llm "claude-opus-4-8" > "$REPORT" 2>&1
  EXIT_CODE=$?
fi

# Enforce report quality: a healthy report is never tiny
REPORT_BYTES=$(wc -c < "$REPORT" 2>/dev/null || echo 0)
STATUS="ok"
if [ $EXIT_CODE -ne 0 ]; then
  STATUS="FAILED (exit $EXIT_CODE)"
elif [ "$REPORT_BYTES" -lt 2000 ]; then
  STATUS="DEGRADED (report only ${REPORT_BYTES}B - format likely ignored)"
fi
log "LLM phase: $STATUS. Report: $REPORT (${REPORT_BYTES}B)"

# ---------------------------------------------------------------------------
# Phase 3: notify + repo sync
# ---------------------------------------------------------------------------
SUMMARY="lint: ${LINT_ISSUES} issue(s); llm: ${STATUS}; report: $(basename "$REPORT")"
if [ "$STATUS" = "ok" ]; then
  notify normal "$SUMMARY"
else
  notify critical "AUDIT PROBLEM - $SUMMARY"
fi

SYNC_SCRIPT="$HOME/.claude/scripts/sync-to-repo.sh"
if [ -x "$SYNC_SCRIPT" ]; then
  log "Running repo sync..."
  "$SYNC_SCRIPT" >> "$REVIEW_LOG" 2>&1 && log "Repo sync completed." || log "Repo sync failed (see sync-to-repo.log)."
fi

echo "" >> "$REVIEW_LOG"
