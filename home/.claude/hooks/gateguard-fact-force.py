#!/usr/bin/env python3
"""
GateGuard Fact-Forcing Hook (PreToolUse: Edit|Write|MultiEdit|Bash)

Forces investigation BEFORE the first edit to each file or a destructive
command. Instead of asking "are you sure?" (which an LLM always answers
"yes"), it demands concrete facts: importers, public API, data schemas,
rollback plan, and the verbatim user instruction. The act of investigating
creates awareness that self-evaluation never does.

Behaviour (all "once" gates are per-session, state expires after 30 min):
  - Edit/Write/MultiEdit : first touch of each file path -> deny + fact gate
  - Bash (destructive)   : first time per unique command -> deny + rollback gate
  - Bash (routine)       : once per session              -> deny + light gate

Allowed without gating: read-only git introspection, edits to .claude/settings*.json,
and any tool call made inside a subagent (the parent already passed first-touch).

Adapted from affaan-m/ecc (gateguard-fact-force.js), reimplemented standalone.

Disable: ECC_GATEGUARD=off
Output: PreToolUse permissionDecision JSON (feeds the gate message back to the agent)
"""

import hashlib
import json
import os
import re
import sys
import tempfile
import time

STATE_DIR = os.environ.get(
    "GATEGUARD_STATE_DIR", os.path.join(os.path.expanduser("~"), ".gateguard")
)
SESSION_TIMEOUT_S = 30 * 60
MAX_CHECKED = 500
ROUTINE_BASH_KEY = "__bash_session__"

DESTRUCTIVE_SQL_DD = re.compile(
    r"\b(drop\s+table|delete\s+from|truncate|dd\s+if=)\b", re.IGNORECASE
)


# --- disable / helpers --------------------------------------------------

def disabled():
    return str(os.environ.get("ECC_GATEGUARD", "")).strip().lower() in (
        "0", "off", "false", "no", "disabled", "disable",
    )


def full_mode():
    # Default is "destructive": only gate destructive bash commands.
    # Set ECC_GATEGUARD_MODE=full to also gate first-touch file edits
    # and the first Bash of each session.
    return str(os.environ.get("ECC_GATEGUARD_MODE", "destructive")).strip().lower() == "full"


def strip_quoted(s):
    s = re.sub(r"'(?:[^'\\]|\\.)*'", "''", s)
    s = re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)
    return s


def segments(command):
    flat = strip_quoted(command)
    # promote subshell delimiters so destructive cmds inside $(...)/`...` are seen
    for _ in range(4):
        before = flat
        flat = re.sub(r"\$\(([^()`]*)\)", r";\1;", flat)
        flat = re.sub(r"`([^`]*)`", r";\1;", flat)
        if flat == before:
            break
    return [seg.strip() for seg in re.split(r"[;|&]+", flat) if seg.strip()]


def basename_cmd(tok):
    return re.sub(r"\.exe$", "", re.sub(r"^.*[\\/]", "", tok), flags=re.IGNORECASE).lower()


def is_destructive_rm(tokens):
    if not tokens or basename_cmd(tokens[0]) != "rm":
        return False
    has_r = has_f = False
    for t in tokens[1:]:
        if t == "--recursive":
            has_r = True
        elif t == "--force":
            has_f = True
        elif t.startswith("-") and not t.startswith("--"):
            if re.search(r"[rR]", t[1:]):
                has_r = True
            if "f" in t[1:]:
                has_f = True
    return has_r and has_f


def is_destructive_git(tokens):
    if not tokens or basename_cmd(tokens[0]) != "git":
        return False
    # find subcommand (skip global opts)
    i, sub, rest = 1, None, []
    while i < len(tokens):
        t = tokens[i]
        if t in ("-c", "-C"):
            i += 2
            continue
        if t.startswith("-"):
            i += 1
            continue
        sub = t.lower()
        rest = tokens[i + 1:]
        break
    if sub is None:
        return False
    if sub == "reset":
        return "--hard" in rest
    if sub == "checkout":
        return "--" in rest
    if sub == "clean":
        return any(t == "--force" or (t.startswith("-") and not t.startswith("--") and "f" in t[1:]) for t in rest)
    if sub == "push":
        with_lease = any(t == "--force-with-lease" or t.startswith("--force-with-lease=") for t in rest)
        bare = any(t == "--force" or t.startswith("--force=") or (t.startswith("-") and not t.startswith("--") and "f" in t[1:]) for t in rest)
        plus = any(re.match(r"^\+(?:[a-zA-Z_/.:]|HEAD)", t) for t in rest)
        return bare or (plus and not with_lease)
    if sub == "commit":
        return "--amend" in rest
    if sub == "rm":
        return any(t.startswith("-") and not t.startswith("--") and re.search(r"[rR]", t[1:]) for t in rest)
    if sub == "switch":
        return any(t in ("--discard-changes", "--force") or (t.startswith("-") and not t.startswith("--") and re.search(r"[fC]", t[1:])) for t in rest)
    return False


def is_destructive_bash(command):
    if DESTRUCTIVE_SQL_DD.search(strip_quoted(command)):
        return True
    for seg in segments(command):
        if DESTRUCTIVE_SQL_DD.search(seg):
            return True
        tokens = seg.split()
        if is_destructive_rm(tokens) or is_destructive_git(tokens):
            return True
    return False


_RO_GIT = {
    "status": lambda a: all(x in ("--porcelain", "--short", "--branch") for x in a),
    "diff": lambda a: len(a) <= 1 and all(x in ("--name-only", "--name-status") for x in a),
    "log": lambda a: all(x == "--oneline" or re.match(r"^--max-count=\d+$", x) for x in a),
    "branch": lambda a: a == ["--show-current"],
}


def is_readonly_git(command):
    t = command.strip()
    if not t or re.search(r"[\r\n;&|><`$()]", t):
        return False
    tokens = t.split()
    if len(tokens) < 2 or basename_cmd(tokens[0]) != "git":
        return False
    fn = _RO_GIT.get(tokens[1].lower())
    return bool(fn and fn(tokens[2:]))


# --- per-session state --------------------------------------------------

def session_key(data):
    for c in (data.get("session_id"), data.get("sessionId"),
              os.environ.get("CLAUDE_SESSION_ID")):
        if c:
            s = re.sub(r"[^a-zA-Z0-9_-]", "_", str(c))
            return s[:64] if len(s) <= 64 else hashlib.sha256(str(c).encode()).hexdigest()[:24]
    tx = data.get("transcript_path") or os.environ.get("CLAUDE_TRANSCRIPT_PATH")
    if tx:
        return "tx-" + hashlib.sha256(os.path.abspath(tx).encode()).hexdigest()[:24]
    proj = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    return "proj-" + hashlib.sha256(os.path.abspath(proj).encode()).hexdigest()[:24]


def state_path(data):
    return os.path.join(STATE_DIR, f"state-{session_key(data)}.json")


def load_state(path):
    try:
        with open(path) as f:
            st = json.load(f)
        if time.time() - st.get("last_active", 0) > SESSION_TIMEOUT_S:
            try:
                os.unlink(path)
            except OSError:
                pass
            return {"checked": [], "last_active": time.time()}
        return st
    except Exception:
        return {"checked": [], "last_active": time.time()}


def mark_checked(path, key):
    st = load_state(path)
    if key in st["checked"]:
        return True
    st["checked"].append(key)
    st["checked"] = st["checked"][-MAX_CHECKED:]
    st["last_active"] = time.time()
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=STATE_DIR, prefix=".st", suffix=".tmp")
        with os.fdopen(fd, "w") as f:
            json.dump(st, f)
        os.replace(tmp, path)
        return True
    except Exception:
        return False


def is_checked(path, key):
    return key in load_state(path).get("checked", [])


# --- gate messages ------------------------------------------------------

def _sanitize(p):
    return re.sub(r"[\x00-\x1f\x7f]", " ", str(p)).strip()[:500]


RECOVERY = ("\n\nRecovery: if GateGuard is blocking setup or repair work, "
            "run this session with ECC_GATEGUARD=off.")


def edit_gate(fp):
    return ("[Fact-Forcing Gate]\n\n"
            f"Before editing {_sanitize(fp)}, present these facts:\n\n"
            "1. List ALL files that import/require this file (use Grep)\n"
            "2. List the public functions/classes affected by this change\n"
            "3. If it reads/writes data, show field names, structure, date format\n"
            "4. Quote the user's current instruction verbatim\n\n"
            "Present the facts, then retry the same operation." + RECOVERY)


def write_gate(fp):
    return ("[Fact-Forcing Gate]\n\n"
            f"Before creating {_sanitize(fp)}, present these facts:\n\n"
            "1. Name the file(s) and line(s) that will call this new file\n"
            "2. Confirm no existing file serves the same purpose (use Glob)\n"
            "3. If it reads/writes data, show field names, structure, date format\n"
            "4. Quote the user's current instruction verbatim\n\n"
            "Present the facts, then retry the same operation." + RECOVERY)


def destructive_gate():
    return ("[Fact-Forcing Gate]\n\n"
            "Destructive command detected. Before running, present:\n\n"
            "1. List all files/data this command will modify or delete\n"
            "2. Write a one-line rollback procedure\n"
            "3. Quote the user's current instruction verbatim\n\n"
            "Present the facts, then retry the same operation.")


def routine_gate():
    return ("[Fact-Forcing Gate]\n\n"
            "Before the first Bash command this session, present:\n\n"
            "1. The current user request in one sentence\n"
            "2. What this specific command verifies or produces\n\n"
            "Present the facts, then retry the same operation." + RECOVERY)


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


# --- main ---------------------------------------------------------------

SETTINGS_RE = re.compile(r"(^|/)\.claude/settings(\.[^/]+)?\.json$")


def in_subagent(data):
    return any(isinstance(data.get(k), str) and data.get(k).strip()
               for k in ("agent_id", "agentId", "parent_tool_use_id", "parentToolUseId"))


def main():
    if disabled():
        sys.exit(0)
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    path = state_path(data)
    raw_tool = (data.get("tool_name") or "")
    tool = {"edit": "Edit", "write": "Write", "multiedit": "MultiEdit", "bash": "Bash"}.get(
        raw_tool.lower(), raw_tool)
    ti = data.get("tool_input", {}) or {}
    sub = in_subagent(data)

    if tool in ("Edit", "Write"):
        if not full_mode():
            sys.exit(0)  # destructive-only mode: never gate file edits
        fp = ti.get("file_path", "")
        if not fp or SETTINGS_RE.search(fp.replace("\\", "/").lower()) or sub:
            sys.exit(0)
        if not is_checked(path, fp):
            mark_checked(path, fp)
            deny(edit_gate(fp) if tool == "Edit" else write_gate(fp))
        sys.exit(0)

    if tool == "MultiEdit":
        if not full_mode():
            sys.exit(0)  # destructive-only mode: never gate file edits
        if sub:
            sys.exit(0)
        for edit in ti.get("edits", []) or []:
            fp = edit.get("file_path", "")
            if fp and not SETTINGS_RE.search(fp.replace("\\", "/").lower()) and not is_checked(path, fp):
                mark_checked(path, fp)
                deny(edit_gate(fp))
        sys.exit(0)

    if tool == "Bash":
        command = ti.get("command", "")
        if is_readonly_git(command):
            sys.exit(0)
        if is_destructive_bash(command):
            key = "__destructive__" + hashlib.sha256(command.encode()).hexdigest()[:16]
            if not is_checked(path, key):
                mark_checked(path, key)
                deny(destructive_gate())
            sys.exit(0)
        if full_mode() and not is_checked(path, ROUTINE_BASH_KEY):
            mark_checked(path, ROUTINE_BASH_KEY)
            deny(routine_gate())
        sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
