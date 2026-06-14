#!/bin/bash
# Intelligent Agent Review - runs weekly via cron
# Analyzes agent roster, checks for improvements, and applies changes
# Uses Claude itself to make smart decisions about agent management

# Ensure PATH includes common locations for cron environment
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node/ 2>/dev/null | tail -1)/bin:$PATH"

LOG_DIR="/home/geoff/.claude/logs"
REVIEW_LOG="$LOG_DIR/agent-review.log"
REPORT_DIR="$LOG_DIR/agent-reviews"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H%M)
REPORT="$REPORT_DIR/review-$TIMESTAMP.md"

# Cleanup trap - remove temp clone on exit regardless of success/failure
cleanup() {
  rm -rf /tmp/cct-review
}
trap cleanup EXIT

echo "=== Agent Review: $(date) ===" >> "$REVIEW_LOG"

# Verify claude is available
if ! command -v claude &>/dev/null; then
  echo "ERROR: claude not found in PATH ($PATH)" >> "$REVIEW_LOG"
  exit 1
fi

# Run Claude in non-interactive mode with the review prompt
claude --dangerously-skip-permissions -p \
  --output-format text \
  --effort max \
  "$(cat <<'PROMPT'
You are performing the weekly intelligent agent review. Your job is to analyze, optimize, and evolve the agent roster at ~/.claude/agents/.

## Step 1: Audit Current Agents

Read every agent file in ~/.claude/agents/ and catalog each agent:
- Agent name, description, model, tools listed in frontmatter
- Quality of the description (does it include concrete examples with context/user/assistant/commentary?)
- Whether it overlaps significantly with another agent
- Whether its instructions are current and well-written

For each agent, verify the frontmatter is complete and valid:
- `name`: present and matches filename
- `description`: present, detailed, includes usage examples
- `model`: set appropriately by tier — `fable` for the most critical/complex high-blast-radius
  agents (architects, code-reviewer, security-*, multi-agent-coordinator, refactoring-expert,
  quality-engineer), `opus` for other complex work, `sonnet` for standard, `haiku` for lightweight.
  IMPORTANT: `fable` is the current top tier (above opus). NEVER downgrade an agent already set to
  `model: fable` back to `opus` — treat existing `fable` pins as intentional and preserve them.
- `tools`: lists the tools the agent actually needs (Read, Write, Edit, Bash, Glob, Grep, etc.)

## Step 2: Check for Repo Updates

Clone https://github.com/davila7/claude-code-templates.git (shallow, to /tmp/cct-review) and compare:
- Are there new agents in the repo that would fill gaps in the current roster?
- Have any installed agents been updated upstream with better instructions?
- Are there agents in categories not currently covered?

Focus on high-value additions — don't bloat the roster. Quality over quantity.

## Step 3: Analyze Tool & Capability Alignment

Read ~/.claude/settings.json and any .mcp.json files to check:
- Do agents reference tools/MCPs that aren't available?
- Are there installed MCPs/skills that no agent leverages?
- Could agent instructions be updated to use available tools better?

Additionally, verify agents are aware of and leverage current Claude Code capabilities:
- **ToolSearch**: Agents can discover deferred tools at runtime — agents doing research or complex work should know this
- **MCP tools**: Check which MCP servers are configured (settings.json mcpServers section) and ensure relevant agents reference them (e.g., playwright for QA agents, context7 for documentation agents)
- **Skills system**: Agents can invoke skills via the Skill tool — ensure agents that do builds, tests, commits, etc. know about relevant skills
- **Agent tool**: Agents can spawn sub-agents — ensure orchestration agents (multi-agent-coordinator, task-distributor) have current agent roster in their instructions
- **Worktree isolation**: The --worktree flag and isolation: "worktree" parameter let agents work in isolated copies — ensure agents doing risky operations (refactoring, large edits) mention this capability
- **LSP tool**: Language Server Protocol integration for code intelligence — ensure code analysis agents know about this
- **NotebookEdit**: For Jupyter notebook editing — ensure data-engineer and python-expert mention this if relevant
- **TaskCreate/TaskUpdate/TaskGet**: Task management tools — ensure orchestration and PM agents reference these
- **WebFetch/WebSearch**: Web access tools — ensure research agents reference these
- **CronCreate/CronList/CronDelete**: Scheduling tools — ensure devops agents are aware

## Step 4: Check AGENT_ROUTER.md Alignment

Read ~/.claude/AGENT_ROUTER.md and verify:
- Does the available agents table match what's actually installed?
- Are any installed agents missing from the router?
- Is the coordinator instruction still accurate?
- Does the agent count in the coordinator instructions match reality?

## Step 5: Take Action

For each finding, take the appropriate action:
- **Update**: Edit agent files to improve instructions, fix tool references, or incorporate better patterns from upstream
- **Add**: Install new agents from the repo using `npx claude-code-templates@latest --agent "category/name" --yes` if they fill a real gap
- **Remove**: Delete agents that are redundant or unused (only if clearly duplicative)
- **Router sync**: Update AGENT_ROUTER.md to reflect any roster changes

## Step 6: Write Report

Write a detailed, structured report to STDOUT using this exact format:

```markdown
# Agent Review Report — [DATE]

## Summary
- **Agents reviewed**: [count]
- **Updates made**: [count]
- **Agents added**: [count]
- **Agents removed**: [count]
- **Router changes**: yes/no

## Agent Audit Results

### [agent-name.md]
- **Status**: OK | Updated | Added | Removed
- **Model**: [model]
- **Tools**: [tool list]
- **Findings**: [what was found — metadata issues, stale instructions, missing capabilities, etc.]
- **Action taken**: [what was changed, or "None needed"]

(Repeat for EVERY agent)

## Capability Alignment

### New Capabilities Integrated
- [List which agents were updated to reference new tools/features and what was added]

### MCP Coverage
- [Which MCPs are configured and which agents reference them]
- [Any gaps where an MCP exists but relevant agents don't mention it]

### Missing Tool References
- [Agents that should reference tools but don't]

## Upstream Comparison
- **New agents in repo**: [list any, note if added or skipped and why]
- **Updated agents upstream**: [list any, note if changes were pulled in]

## Router Sync
- [Changes made to AGENT_ROUTER.md, or "No changes needed"]

## Gaps & Recommendations
- [Areas not acted on that the user should consider]
- [Recommendations for next review cycle]
```

Do NOT compress or summarize this report. Every agent must have its own section.

## Rules
- Be conservative with removals — only remove clearly redundant agents
- Be moderate with additions — only add agents that fill real gaps
- Be liberal with updates — improve instructions freely
- Always update AGENT_ROUTER.md if the roster changes
- Clean up /tmp/cct-review when done
- You MUST apply changes directly using Edit/Write tools. Do NOT just propose changes — actually make them. You have full write permissions via --dangerously-skip-permissions. If you identify an improvement, apply it immediately.
- After making changes, verify them by reading the modified files
- Keep agent description fields in frontmatter to 1-2 sentences max (examples go in the body only)
PROMPT
)" > "$REPORT" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "Review completed successfully. Report: $REPORT" >> "$REVIEW_LOG"
else
  echo "Review completed with errors (exit $EXIT_CODE). Report: $REPORT" >> "$REVIEW_LOG"
fi

# Sync the (possibly updated) agents/scripts to the claude-agents git repo
# and push to GitHub. Runs regardless of review exit code so roster changes
# are never lost; sync-to-repo.sh is a no-op when there's nothing to commit.
SYNC_SCRIPT="$HOME/.claude/scripts/sync-to-repo.sh"
if [ -x "$SYNC_SCRIPT" ]; then
  echo "Running repo sync..." >> "$REVIEW_LOG"
  "$SYNC_SCRIPT" >> "$REVIEW_LOG" 2>&1 \
    && echo "Repo sync completed." >> "$REVIEW_LOG" \
    || echo "Repo sync failed (see sync-to-repo.log)." >> "$REVIEW_LOG"
fi

echo "" >> "$REVIEW_LOG"
