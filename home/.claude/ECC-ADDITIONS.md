# ECC Integration — What Was Added & How to Tune It

Cherry-picked from [affaan-m/ecc](https://github.com/affaan-m/ecc) on 2026-06-04.
Only the pieces your setup *lacked* were added (your 29 agents, claude-mem,
beads, ralph-loop already covered the rest). Nothing from ECC was installed
wholesale — no duplicate agents or commands.

## 1. Language coding rules  →  `~/.claude/rules/ecc/`
53 always-follow rule files across: common, python, typescript, react, web,
php, golang, rust, java. `common/` and `web/` are autoloaded at session start;
the language subdirs are lazy-loaded — see `rules/ecc/INDEX.md`. Wired into
`CLAUDE.md` under "Language Coding Standards".

## 2. Guard hooks  →  `~/.claude/hooks/`  (registered in `settings.json`)

### `gateguard-fact-force.py`  (Edit|Write|MultiEdit|Bash)
Default mode is **destructive-only** (set 2026-06-05 after the full mode proved too
token/latency-heavy). It gates only destructive bash (`rm -rf`, `git reset --hard`,
`git push --force`, `drop table`, `dd if=`, …) once per unique command, demanding a
target list + one-line rollback + the verbatim user instruction. File edits and
routine bash are **not** gated. Per-session state in `~/.gateguard/`, 30-min expiry.
- **Modes:** `ECC_GATEGUARD_MODE=destructive` (default) | `ECC_GATEGUARD_MODE=full`
  (also gates each file's first touch + the first Bash of a session — the original
  "fact-forcing" behavior; enforces the "no reactive codebase changes" rule but adds
  a deny→retry round-trip per new file).
- Allows read-only git introspection ungated; skips subagent tool calls.
- **Disable entirely:** `ECC_GATEGUARD=off`

### `config-protection.py`  (Edit|Write|MultiEdit)
Blocks edits to **existing** linter/formatter configs (eslint, prettier, biome,
ruff, flake8, mypy, stylelint, markdownlint, php-cs-fixer, golangci) so the
agent fixes the code instead of weakening the rules. Allows first-time creation.
- **Disable:** `ECC_CONFIG_PROTECTION=off`

Both emit PreToolUse `permissionDecision: deny` JSON, so the gate message is fed
back to the agent as actionable feedback (not a silent block).

## 3. Context modes  →  `~/.claude/contexts/`
`dev.md`, `review.md`, `research.md` — swappable posture files. Invoke on demand,
e.g. "load the review context" before a PR review, or paste into a subagent prompt.

## Tuning cheatsheet
| Want to… | Do this |
|---|---|
| Turn off GateGuard for a session | `ECC_GATEGUARD=off claude …` |
| Re-enable full fact-forcing (file + bash gates) | `ECC_GATEGUARD_MODE=full claude …` |
| Turn off config protection | `ECC_CONFIG_PROTECTION=off claude …` |
| Add a protected config | edit `PROTECTED_FILES` in `config-protection.py` |
| Add a destructive pattern | edit `is_destructive_*` in `gateguard-fact-force.py` |
| Add a language ruleset | copy from ECC `rules/<lang>/` into `rules/ecc/<lang>/` + add to INDEX.md |

## Deliberately NOT taken
ECC's 63 agents (dupes of yours), its `sc:*`/`commit`/`code-review` commands
(dupes), AgentShield (overlaps your secret-scanner), the Tkinter dashboard, and
the multi-harness adapters (.cursor/.zed/.codex — you're Claude Code only).
