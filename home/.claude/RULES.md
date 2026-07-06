# RULES.md - Core Operational Rules

Simple actionable rules for Claude Code operation.

## Core Operational Rules

### Task Management Rules
- TodoWrite(3+ tasks) → Execute → Track progress (beads for complex/multi-session work)
- Use batch tool calls when possible, sequential only when dependencies exist
- Always validate before execution, verify after completion
- Run lint/typecheck before marking tasks complete
- Use beads + ralph (ideate-and-build / specs-to-ralph) for complex multi-session workflows
- Maintain ≥90% context retention across operations

### File Operation Security
- Always use Read tool before Write or Edit operations
- Use absolute paths only, prevent path traversal attacks
- Prefer batch operations and transaction-like behavior
- Never commit automatically unless explicitly requested

### Framework Compliance
- Check package.json/requirements.txt before using libraries
- Follow existing project patterns and conventions
- Use project's existing import styles and organization
- Respect framework lifecycles and best practices

### Systematic Codebase Changes
- **MANDATORY**: Complete project-wide discovery before any changes
- Search ALL file types for ALL variations of target terms
- Document all references with context and impact assessment
- Plan update sequence based on dependencies and relationships
- Execute changes in coordinated manner following plan
- Verify completion with comprehensive post-change search
- Validate related functionality remains working
- Use the Agent tool (subagent searches) when scope uncertain

## Quick Reference

### Do
✅ Read before Write/Edit/Update
✅ Use absolute paths
✅ Batch tool calls
✅ Validate before execution
✅ Check framework compatibility
✅ Preserve context across operations
✅ Use quality gates (see AGENT_ROUTER.md)
✅ Complete discovery before codebase changes
✅ Verify completion with evidence

### Don't
❌ Skip Read operations
❌ Use relative paths
❌ Auto-commit without permission
❌ Ignore framework patterns
❌ Skip validation steps
❌ Mix user-facing content in config
❌ Override safety protocols
❌ Make reactive codebase changes
❌ Mark complete without verification

### Auto-Triggers
- Workflow Selection (AGENT_ROUTER.md): match request to superpowers / gstack / beads+ralph before routing to agents
- MCP servers: task type + performance requirements
- Quality gates: verify agent output before presenting (AGENT_ROUTER.md)