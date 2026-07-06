@AGENT_ROUTER.md
@RULES.md

## gstack
gstack is installed at `~/.claude/skills/gstack` (router skill: `gstack`). Use its `/browse` skill for all web browsing; never use `mcp__claude-in-chrome__*` tools. Key entry points: `/office-hours` and `/spec` (idea → spec), `/autoplan` (auto plan review), `/review` (branch review), `/qa` (browser QA), `/ship` (release), `/cso` (security audit), `/investigate` (debugging), `/design-review`. Run `/gstack-upgrade` to update; full catalog via the `gstack` router skill.

## Language Coding Standards
When doing substantive coding work, consult the relevant language rules in
`~/.claude/rules/ecc/` — see `~/.claude/rules/ecc/INDEX.md` for the lazy-load map.
Pull only the language(s) in play; don't preload everything.

