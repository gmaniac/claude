#!/bin/bash
# Update claude-code-templates agents to latest versions
# Run via cron: 0 3 * * 0 (weekly Sunday 3am)

LOG="/home/geoff/.claude/logs/agent-updates.log"
mkdir -p "$(dirname "$LOG")"

echo "=== Agent Update: $(date) ===" >> "$LOG"

# Agents sourced from davila7/claude-code-templates
REPO_AGENTS=(
  "development-team/backend-architect"
  "development-team/backend-developer"
  "development-team/frontend-developer"
  "development-team/fullstack-developer"
  "development-team/test-generator"
  "development-tools/code-reviewer"
  "development-tools/debugger"
  "development-tools/performance-engineer"
  "data-ai/data-engineer"
  "devops-infrastructure/devops-engineer"
  "documentation/technical-writer"
  "expert-advisors/multi-agent-coordinator"
  "expert-advisors/workflow-orchestrator"
  "expert-advisors/task-distributor"
  "security/security-auditor"
  "security/security-engineer"
)

# Join with commas for the CLI
AGENT_LIST=$(IFS=,; echo "${REPO_AGENTS[*]}")

echo "Updating ${#REPO_AGENTS[@]} agents..." >> "$LOG"

npx claude-code-templates@latest --agent "$AGENT_LIST" --yes >> "$LOG" 2>&1

if [ $? -eq 0 ]; then
  echo "Update completed successfully." >> "$LOG"
else
  echo "Update completed with errors. Check log." >> "$LOG"
fi

echo "" >> "$LOG"
