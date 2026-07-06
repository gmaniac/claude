# AGENT_ROUTER.md - Agent Routing, Workflows, Loops & Beads

## Core Directive

Route substantive multi-domain work through **multi-agent-coordinator** (it has the Agent tool and spawns specialists). Handle directly, no coordinator:
- Simple questions, single-file edits, trivial fixes
- Conversational back-and-forth / brainstorming / clarifying questions
- Work that maps cleanly onto ONE specialist — launch that agent directly
- Work covered by a Workflow Selection row below — use that workflow

## Workflow Selection

Before routing to agents, check whether a purpose-built workflow already covers the request:

| Situation | Use |
|---|---|
| Vague idea → requirements | superpowers `brainstorming` skill |
| Feature planning | Plan mode or superpowers `writing-plans` |
| Executing a reviewed plan | superpowers `subagent-driven-development` / `executing-plans` |
| TDD enforcement | superpowers `test-driven-development` |
| Debugging | superpowers `systematic-debugging`; debugger / root-cause-analyst agents; gstack `/investigate` |
| Spec → tracked issues → autonomous build | `ideate-and-build` / `specs-to-ralph` (beads + ralph CLI) |
| Plan review (product/eng/design) | gstack `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, or `/autoplan` |
| Branch review / ship / browser QA / security audit | gstack `/review`, `/ship`, `/qa`, `/cso` |
| UI look-and-feel work | frontend-design plugin + `rules/ecc/web/*` |

## Routing Algorithm

1. Trivial → handle directly.
2. Matches a Workflow Selection row → use that workflow.
3. MODERATE (3-10 steps, single domain, 1-2 agents) → launch the right specialist(s) directly; parallel when independent, sequential when dependent.
4. COMPLEX (10+ steps, multi-domain, 3+ agents) → multi-agent-coordinator + beads tracking.
5. Verify agent output before presenting (Quality Gates below).

## Agent Roster

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
| system-architect | System design, scalability, long-term decisions | fable |
| backend-architect | Backend design, data integrity, fault tolerance | fable |
| frontend-architect | UI architecture, accessibility, performance | fable |
| devops-architect | Infrastructure automation, reliability, observability | fable |

### Analysis & Investigation
| Agent | Specialty | Model |
|-------|-----------|-------|
| debugger | Bug diagnosis, root cause, stack traces | sonnet |
| root-cause-analyst | Evidence-based investigation, hypothesis testing | sonnet |
| performance-engineer | Bottlenecks, optimization, load testing | sonnet |
| deep-research-agent | Comprehensive multi-source research | opus |
| requirements-analyst | Requirements discovery, specifications | opus |
| business-panel-experts | Business strategy, multi-framework analysis | opus |
| data-engineer | Data pipelines, ETL, data quality | sonnet |

### Quality & Security
| Agent | Specialty | Model |
|-------|-----------|-------|
| code-reviewer | Code quality, best practices, PR reviews | fable |
| security-auditor | Security assessments, compliance, vulnerabilities | fable |
| security-engineer | Security implementation, hardening | fable |
| quality-engineer | Testing strategy, edge cases, QA | fable |
| test-generator | Auto-generate test suites | sonnet |
| refactoring-expert | Technical debt, clean code, refactoring | fable |

### Communication & Learning
| Agent | Specialty | Model |
|-------|-----------|-------|
| technical-writer | Documentation, API docs, guides | haiku |
| learning-guide | Teaching concepts, progressive learning | opus |
| socratic-mentor | Discovery learning through questioning | opus |
| pm-agent | Implementation documentation, knowledge base | opus |

### Orchestration
| Agent | Specialty | Model |
|-------|-----------|-------|
| multi-agent-coordinator | Cross-agent coordination, dependency management | fable |
| task-distributor | Workload balancing for 4+ parallel agents | haiku |
| workflow-orchestrator | Complex process flows, state machines | opus |

## Coordinator Guidance

When launching multi-agent-coordinator, instruct it to:
1. Analyze domains → select specialists → parallel for independent work, sequential for dependencies; task-distributor for 4+ parallel agents; workflow-orchestrator for complex multi-step processes.
2. If 3+ agents, 10+ steps, or multi-session: create a beads epic + child issues with dependencies BEFORE launching agents; update statuses as agents complete; `bd sync` at session end.
3. Prefer specialists over generalists; architects design, developers implement; pair implementation with test-generator; add security-auditor for auth/payment/user-data work.
4. Use `isolation: "worktree"` for agents making risky multi-file changes.
5. Surface MCP capabilities in agent prompts when relevant: Playwright/Chrome DevTools (browser, perf traces), Context7 (library docs — prefer over web search), GitHub, PostgreSQL, SigNoz/Sentry (observability), shadcn/Magic (UI components), Morphllm (bulk edits), Memory, Sequential-thinking, Tavily/Fetch (web research).
6. Prefer project-standard skills over ad-hoc reimplementation: generate-tests, test-coverage, code-review, security-audit, dependency-audit, refactor-code, performance-audit, generate-api-documentation, init:*, setup-docker-containers, prepare-release.

## Beads Integration

| Session type | Tracking |
|---|---|
| Trivial (1-2 steps) | none |
| Moderate (3-10 steps, 1-2 agents) | TodoWrite / coordinator manages |
| Complex (10+ steps, 3+ agents, sequential deps) | beads epic + child issues |
| Multi-session (days/weeks, survives compaction) | beads with full dependency graph |

Core flow: `bd create "Epic" -t epic -p 1 --json` → child issues with `bd dep add <child> <epic> --type parent-child` and `--type blocks` for ordering → `bd update <id> --status in_progress` when an agent starts → `bd close <id>` when it finishes → discovered work gets `--type discovered-from` → `bd sync` before session end. Resume via `bd ready --json` + `bd list --status in_progress --json`. Beads beats TodoWrite for complex work because it survives compaction, tracks dependencies, and resumes across sessions.

## Loop Integration Rules

### Default: no polling loop
Background agents launched via the Agent tool are harness-tracked: they fire a task-notification automatically when they finish or fail. Do NOT set up a /loop to "check agent progress" — polling adds no information, re-sends the full conversation each poll, and clutters the transcript. Wait for the notification.

### Fallback wakeup (long runs only)
For runs expected to exceed ~30 minutes, set at most ONE long fallback wakeup (e.g. /loop 30m or a single ScheduleWakeup) purely as a liveness check in case a notification is missed. On wakeup: check status once, report, cancel the loop if work completed.

### Short-interval polling: external state only
Fixed 2-5m polls are justified ONLY for state outside the harness that cannot push notifications: CI pipelines, deploys, migrations, remote queues, third-party job APIs, canary metrics. Use the longest interval that meets the reaction-time need, and always give the loop an exit condition plus a max duration.

### Beads in loop checks
Only when beads issues are open for the current work: on each wakeup run `bd ready --json` and `bd list --status in_progress --json` once, update statuses for completed agents, report newly unblocked work. Never run bd commands on a timer with no open issues.

### Ralph rules
- Ralph IS the loop. Never stack a /loop or wakeup poll on top of a running ralph (CLI or plugin) — it double-spends. Observe via `ralph --status` / `ralph-monitor` / `bd ready`.
- Prefer the ralph CLI (fresh context per iteration) over the ralph-loop plugin for anything beyond ~5 iterations; in-session re-feeding grows context cost every turn.
- When using the ralph-loop plugin, ALWAYS pass `--completion-promise` and `--max-iterations`.
- The ralph CLI is capped at 50 loops / 8h wall-clock per run (override: RALPH_MAX_TOTAL_LOOPS / RALPH_MAX_WALL_HOURS; 0 disables).
- Ralph workdirs should disable claude-mem (and warp) via project-local `.claude/settings.json` `enabledPlugins` — otherwise every iteration pays SessionStart context injection, per-tool-call observations, and an LLM summarization on Stop.

### When NOT to loop
- Any harness-tracked agent work (notifications cover it)
- Simple questions, single-file edits, conversations
- Tasks completing in under ~10 minutes
- While ralph is driving the work

## Quality Gates

After agents return results:
1. **Verify** — read agent results before presenting to the user
2. **Security** — code touching auth/payments/user data → security-auditor review
3. **Tests** — code written → suggest test-generator; gstack `/qa` for web flows
4. **Docs** — API created → suggest technical-writer
5. **Beads** — close completed issues, file discovered work, `bd sync`
