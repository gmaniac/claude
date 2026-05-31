# AGENT_ROUTER.md - Auto-Agent Routing, Loop & Beads Integration

## Core Directive

**ALWAYS route work through multi-agent-coordinator.** Do NOT do substantive work yourself when agents exist for it. The coordinator analyzes the request, selects the right specialist agent(s), manages dependencies between them, and handles failures.

The only exceptions where you handle directly (no coordinator):
- Simple questions answerable in 1-2 sentences
- Single-file edits or trivial fixes
- Conversational back-and-forth / brainstorming
- Clarifying questions before work begins

Everything else goes through the coordinator.

## Routing Algorithm

```
1. User makes a request
2. Is it trivial? (simple question, 1-line fix, conversation)
   YES -> Handle directly, no agent needed
   NO  -> Continue to step 3
3. Assess complexity:
   - MODERATE (3-10 steps, single domain): coordinator only
   - COMPLEX (10+ steps, multi-domain, multi-agent): coordinator + beads tracking
4. Launch multi-agent-coordinator with:
   - The user's full request
   - Context: available agents list (below)
   - Instruction: select and launch appropriate specialist(s)
   - Instruction: use parallel agents when tasks are independent
   - Instruction: use sequential agents when tasks depend on each other
   - If COMPLEX: instruction to create beads epic and child issues (see Beads Integration)
5. Set up /loop monitoring based on task type (see Loop Rules below)
6. Coordinator returns results -> present to user
7. Apply quality gates (see below)
8. If beads were created: update issue statuses and close completed work
```

## Available Agents for Coordinator

The coordinator should know about and select from these specialists:

### Development
| Agent | Specialty | Model |
|-------|-----------|-------|
| backend-developer | APIs, microservices, server-side code | sonnet |
| frontend-developer | UI, components, React/Vue/Angular | sonnet |
| fullstack-developer | Cross-layer features (DB + API + UI) | sonnet |
| python-expert | Python projects, scripts, automation | sonnet |
| prompt-engineer | Prompt design, LLM optimization, eval harnesses | sonnet |
| devops-engineer | CI/CD, Docker, K8s, infrastructure | sonnet |

### Architecture & Design
| Agent | Specialty | Model |
|-------|-----------|-------|
| system-architect | System design, scalability, long-term decisions | opus |
| backend-architect | Backend system design, data integrity, fault tolerance | opus |
| frontend-architect | UI architecture, accessibility, performance | opus |
| devops-architect | Infrastructure automation, reliability, observability | opus |

### Analysis & Investigation
| Agent | Specialty | Model |
|-------|-----------|-------|
| debugger | Bug diagnosis, root cause, stack traces | sonnet |
| root-cause-analyst | Evidence-based investigation, hypothesis testing | sonnet |
| performance-engineer | Bottleneck identification, optimization, load testing | sonnet |
| deep-research-agent | Comprehensive research, multi-source exploration | opus |
| requirements-analyst | Requirements discovery, specifications | opus |
| business-panel-experts | Business strategy, multi-framework analysis | opus |
| data-engineer | Data pipelines, ETL, data quality | sonnet |

### Quality & Security
| Agent | Specialty | Model |
|-------|-----------|-------|
| code-reviewer | Code quality, best practices, PR reviews | opus |
| security-auditor | Security assessments, compliance, vulnerability analysis | opus |
| security-engineer | Security implementation, hardening | opus |
| quality-engineer | Testing strategy, edge cases, quality assurance | opus |
| test-generator | Auto-generate test suites from code analysis | sonnet |
| refactoring-expert | Technical debt, clean code, systematic refactoring | opus |

### Communication & Learning
| Agent | Specialty | Model |
|-------|-----------|-------|
| technical-writer | Documentation, API docs, guides | haiku |
| learning-guide | Teaching concepts, progressive learning | opus |
| socratic-mentor | Discovery learning through questioning | opus |
| pm-agent | Implementation documentation, knowledge base | opus |

### Orchestration (coordinator's helpers)
| Agent | Specialty | Model |
|-------|-----------|-------|
| task-distributor | Workload balancing, queue management, SLA tracking | haiku |
| workflow-orchestrator | Process flows, state machines, saga patterns | opus |

## Coordinator Instructions

When launching multi-agent-coordinator, include this context:

```
You are coordinating work across 29 specialist agents (excluding self). Your job:

1. ANALYZE the request - what domains does it touch?
2. SELECT the right agent(s) from the available roster
3. ASSESS complexity - if 3+ agents or 10+ steps, use beads for tracking
4. DECIDE execution strategy:
   - Single agent: simple domain-specific task
   - Parallel agents: independent tasks across domains
   - Sequential agents: tasks with dependencies (design before build, build before test)
   - Use task-distributor for 4+ parallel agents
   - Use workflow-orchestrator for complex multi-step processes
5. If using beads: create epic + child issues with dependencies BEFORE launching agents
6. LAUNCH agents and aggregate their results
7. If using beads: update issue statuses as agents complete
8. VALIDATE output quality before returning

Agent selection principles:
- Prefer specialists over generalists
- Use architect agents for design, developer agents for implementation
- Always pair implementation with testing (suggest test-generator after code)
- Always consider security (suggest security-auditor for auth/payment/data)
- Use opus-model agents for critical/complex work, sonnet for standard implementation
- Use isolation: "worktree" for agents performing risky multi-file changes (refactoring, large edits)

MCP capabilities to surface in agent prompts when relevant:
- Playwright/Chrome DevTools: browser automation, perf traces, Lighthouse audits
- Context7: current library/framework documentation (prefer over web search)
- GitHub: PR diffs, CI status, dependency changes, branch protection
- PostgreSQL: live schema inspection, query plans, RLS validation
- shadcn/Magic: UI component generation and registry browsing
- Memory: cross-session state persistence
- Sequential-thinking: multi-step reasoning chains
- Tavily/Fetch: web research beyond default WebSearch
```

## Beads Integration

### Complexity Threshold

| Session Type | Task Management |
|---|---|
| Trivial (quick fix, question, 1-2 steps) | Direct work, no tracking |
| Moderate (3-10 steps, single domain, 1-2 agents) | Coordinator manages, no beads |
| Complex (10+ steps, multi-domain, 3+ agents) | Beads epic + child issues |
| Multi-session project (spans days/weeks) | Beads with full dependency graph |

### When Coordinator Activates Beads

The coordinator creates beads issues when ANY of these are true:
- 3 or more specialist agents will be launched
- Work has sequential dependencies (agent B needs agent A's output)
- Task will likely survive context compaction (long session)
- User explicitly asks to track the work
- Work spans multiple directories or projects

### Beads Workflow for Complex Tasks

**Step 1: Create Epic**
```bash
bd create "Build user authentication system" -t epic -p 1 --json
```

**Step 2: Create Child Issues for Each Agent's Work**
```bash
# Design phase
bd create "Design auth architecture" -t task -p 1 --json
bd dep add <design-id> <epic-id> --type parent-child

# Implementation phase (parallel)
bd create "Implement auth API endpoints" -t task -p 1 --json
bd create "Implement auth UI components" -t task -p 1 --json
bd dep add <api-id> <epic-id> --type parent-child
bd dep add <ui-id> <epic-id> --type parent-child

# Dependencies: implementation blocks on design
bd dep add <api-id> <design-id> --type blocks
bd dep add <ui-id> <design-id> --type blocks

# Testing phase
bd create "Generate auth test suite" -t task -p 1 --json
bd dep add <test-id> <epic-id> --type parent-child
bd dep add <test-id> <api-id> --type blocks
bd dep add <test-id> <ui-id> --type blocks

# Security audit
bd create "Security audit auth system" -t task -p 1 --json
bd dep add <audit-id> <epic-id> --type parent-child
bd dep add <audit-id> <test-id> --type blocks
```

**Step 3: Track Agent Progress**
As each agent completes, update the corresponding issue:
```bash
bd update <id> --status in_progress   # When agent starts
bd close <id> --reason "Completed"     # When agent finishes
```

**Step 4: Handle Discoveries**
When an agent discovers additional work needed:
```bash
bd create "Fix CORS config for auth endpoints" -t bug -p 1 --json
bd dep add <new-id> <parent-id> --type discovered-from
```

**Step 5: Session End**
Before ending a complex session:
```bash
bd sync  # Flush all changes to git
```

### Why Beads Over TodoWrite for Complex Tasks

| Feature | TodoWrite | Beads |
|---|---|---|
| Survives context compaction | No | Yes (git-backed) |
| Dependency tracking | No (flat list) | Yes (blocks, parent-child) |
| Post-session visibility | Gone | Persistent in .beads/ |
| Cross-session resume | No | Yes (bd ready shows what's next) |
| Multi-agent coordination | No | Yes (each agent = issue) |
| Audit trail | No | Yes (git history) |

### Beads Session Labels

To keep sessions organized, label issues with the session context:
```bash
bd label create "session" --color blue    # One-time setup
bd create "Task name" -t task -p 1 -l session --json
```

For multi-session projects, use descriptive labels:
```bash
bd label create "auth-system" --color green
bd create "Task name" -t task -p 1 -l auth-system --json
```

## Loop Integration Rules

### When to Auto-Loop
After launching the coordinator, set up a `/loop` based on task type:

| Task Type | Loop Interval | Check Prompt |
|-----------|--------------|--------------|
| Implementation (build, code, deploy) | 3m | Check agent progress. Report files changed, errors, completion %. Update beads issue status if tracking. |
| Analysis (audit, review, research) | 5m | Check analysis progress. Report findings, areas remaining. Update beads if tracking. |
| Monitoring (deploys, migrations) | 2m | Check status. Report stage, health, rollback triggers. |
| Testing (test gen, coverage) | 3m | Check test progress. Report pass/fail, coverage %, blockers. Update beads if tracking. |

### Loop + Beads Integration
When both loop and beads are active, the loop check should:
1. Check agent task progress
2. Run `bd list --status in_progress --json` to show active issues
3. Update issue status if an agent has completed
4. Run `bd ready --json` to show what's unblocked next
5. Report blocked issues if agents are waiting on dependencies

### When NOT to Loop
- Simple questions or explanations
- Single-file edits or quick fixes
- Conversations and brainstorming
- Tasks completing in under 2 minutes
- Coordinator is only selecting agents (not doing long work)

## Quality Gates

After coordinator returns results:

1. **Verify** - Read agent results before presenting to user
2. **Security check** - If code touches auth, payments, or user data: auto-launch security-engineer review
3. **Test check** - If code was written: suggest launching test-generator
4. **Doc check** - If API was created: suggest launching technical-writer
5. **Beads check** - If tracking with beads: close completed issues, file discovered work, run `bd sync`

## Examples

### Simple routing (single agent, no beads)
```
User: "This API endpoint is returning 500 errors"
-> Launch coordinator
-> Coordinator selects: debugger + root-cause-analyst
-> No beads (2 agents, interactive diagnosis)
-> No loop (diagnosis is interactive)
```

### Moderate routing (parallel agents, no beads)
```
User: "Review this PR"
-> Launch coordinator
-> Coordinator selects: code-reviewer + security-auditor + quality-engineer (parallel)
-> No beads (parallel review, no dependencies)
-> /loop 5m check review progress
```

### Complex routing (sequential agents, beads tracking)
```
User: "Build a user authentication system"
-> Launch coordinator
-> Coordinator creates beads epic: "Build auth system"
-> Coordinator creates child issues with dependencies:
   design (unblocked) -> implement-api + implement-ui (parallel) -> tests -> security-audit
-> Coordinator launches agents following dependency order
-> /loop 3m check progress + update beads statuses
-> On completion: close all issues, bd sync
```

### Large orchestration (many agents, full beads + loop)
```
User: "Modernize our payment system"
-> Launch coordinator
-> Coordinator creates beads epic with 8+ child issues
-> Coordinator engages workflow-orchestrator for process planning
-> Coordinator uses task-distributor for work assignment
-> Launches agents in phases, updating beads as each completes
-> /loop 3m check coordination + beads status
-> Discovers additional work -> files new beads issues linked to parent
-> On completion: close epic, bd sync, report summary
```

### Resuming from previous session
```
User: "Continue where we left off on the auth system"
-> Run: bd list -l auth-system --json
-> Run: bd ready --json
-> Show user what's completed and what's ready
-> Launch coordinator with remaining work context
-> Continue with beads tracking from existing issues
```
