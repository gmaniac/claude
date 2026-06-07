#!/usr/bin/env python3
"""
Config Protection Hook (PreToolUse: Edit|Write|MultiEdit)

Blocks modifications to existing linter/formatter config files. Agents
frequently weaken these configs to make checks pass instead of fixing the
actual code. This hook steers the agent back to fixing the source.

Allows first-time creation of a config (legitimate bootstrap) — only an
existing config being modified is blocked.

Adapted from affaan-m/ecc (config-protection.js), reimplemented standalone.

Disable: set ECC_CONFIG_PROTECTION=off
Output: PreToolUse permissionDecision JSON (feeds the reason back to the agent)
"""

import json
import os
import sys

PROTECTED_FILES = {
    # ESLint (legacy + v9 flat config)
    ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json",
    ".eslintrc.yml", ".eslintrc.yaml",
    "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
    "eslint.config.ts", "eslint.config.mts", "eslint.config.cts",
    # Prettier
    ".prettierrc", ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.json",
    ".prettierrc.yml", ".prettierrc.yaml",
    "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs",
    # Biome
    "biome.json", "biome.jsonc",
    # Ruff (Python) — note: pyproject.toml deliberately excluded (also holds deps)
    ".ruff.toml", "ruff.toml",
    # Mypy / flake8
    ".flake8", "mypy.ini",
    # Shell / Style / Markdown
    ".shellcheckrc", ".stylelintrc", ".stylelintrc.json", ".stylelintrc.yml",
    ".markdownlint.json", ".markdownlint.yaml", ".markdownlintrc",
    # PHP
    ".php-cs-fixer.php", ".php-cs-fixer.dist.php", "phpcs.xml", "phpcs.xml.dist",
    # Go
    ".golangci.yml", ".golangci.yaml", ".golangci.toml",
}


def disabled():
    return str(os.environ.get("ECC_CONFIG_PROTECTION", "")).strip().lower() in (
        "0", "off", "false", "no", "disabled",
    )


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def main():
    if disabled():
        sys.exit(0)
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    ti = data.get("tool_input", {}) or {}
    paths = []
    if ti.get("file_path"):
        paths.append(ti["file_path"])
    for edit in ti.get("edits", []) or []:
        if edit.get("file_path"):
            paths.append(edit["file_path"])

    for fp in paths:
        basename = os.path.basename(fp)
        if basename not in PROTECTED_FILES:
            continue
        # Allow first-time creation; only block edits to an existing config.
        # Fail closed on any stat error other than "not found".
        exists = True
        try:
            os.lstat(fp)
        except FileNotFoundError:
            exists = False
        except OSError:
            exists = True  # EACCES/EPERM/ELOOP — never silently weaken the guard
        if exists:
            deny(
                f"BLOCKED: Modifying {basename} is not allowed. "
                "Fix the source code to satisfy the linter/formatter instead of "
                "weakening the config. If this is a legitimate config change, "
                "set ECC_CONFIG_PROTECTION=off for this session."
            )

    sys.exit(0)


if __name__ == "__main__":
    main()
