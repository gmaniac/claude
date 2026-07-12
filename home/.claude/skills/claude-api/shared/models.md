# Claude Model Catalog

**Only use exact model IDs listed in this file.** Never guess or construct model IDs — incorrect IDs will cause API errors. Use aliases wherever available. For the latest information, WebFetch the Models Overview URL in `shared/live-sources.md`. (Catalog refreshed from live docs: 2026-07-12.)

## Current Models (recommended)

| Friendly Name    | Alias (use this)   | Full ID                     | Context | Max Output | Status |
|------------------|--------------------|-----------------------------|---------|------------|--------|
| Claude Fable 5   | `claude-fable-5`   | —                           | 1M      | 128K       | Active |
| Claude Opus 4.8  | `claude-opus-4-8`  | —                           | 1M      | 128K       | Active |
| Claude Sonnet 5  | `claude-sonnet-5`  | —                           | 1M      | 128K       | Active |
| Claude Haiku 4.5 | `claude-haiku-4-5` | `claude-haiku-4-5-20251001` | 200K    | 64K        | Active |

### Model Descriptions

- **Claude Fable 5** — Anthropic's most capable widely released model; next-generation intelligence for long-running agents. Adaptive thinking is always on. $10/$50 per MTok. Note: Fable 5 uses the tokenizer introduced with Claude Opus 4.7 — the same text produces roughly 30% more tokens than pre-4.7 models.
- **Claude Opus 4.8** — The docs-recommended default for complex agentic coding and enterprise work. Supports adaptive thinking; `effort` defaults to `high` on all surfaces. $5/$25 per MTok.
- **Claude Sonnet 5** — Best combination of speed and intelligence. Supports adaptive thinking. $3/$15 per MTok (introductory $2/$10 through Aug 31, 2026).
- **Claude Haiku 4.5** — Fastest model with near-frontier intelligence; uses extended thinking (not adaptive). $1/$5 per MTok.

> **Claude Mythos 5** (`claude-mythos-5`) shares Fable 5's specs and pricing but is invitation-only (Project Glasswing, defensive cybersecurity workflows) — do not default to it; it will error without approved access.

## Legacy Models (still active)

| Friendly Name     | Alias (use this)    | Full ID                      | Status |
|-------------------|---------------------|------------------------------|--------|
| Claude Opus 4.7   | `claude-opus-4-7`   | —                            | Active |
| Claude Opus 4.6   | `claude-opus-4-6`   | —                            | Active |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | —                            | Active |
| Claude Sonnet 4.5 | `claude-sonnet-4-5` | `claude-sonnet-4-5-20250929` | Active |
| Claude Opus 4.5   | `claude-opus-4-5`   | `claude-opus-4-5-20251101`   | Active |

## Deprecated Models (retiring soon)

| Friendly Name   | Alias (use this) | Full ID                    | Status                                                 |
|-----------------|------------------|----------------------------|--------------------------------------------------------|
| Claude Opus 4.1 | `claude-opus-4-1`| `claude-opus-4-1-20250805` | Deprecated — retires Aug 5, 2026; migrate to Opus 4.8  |

Claude Sonnet 4 (`claude-sonnet-4-20250514`), Claude Opus 4 (`claude-opus-4-20250514`), and Claude Haiku 3 (`claude-3-haiku-20240307`) no longer appear in the current models overview — verify against live docs before using.

## Retired Models (no longer available)

| Friendly Name     | Full ID                       | Retired     |
|-------------------|-------------------------------|-------------|
| Claude Sonnet 3.7 | `claude-3-7-sonnet-20250219`  | Feb 19, 2026 |
| Claude Haiku 3.5  | `claude-3-5-haiku-20241022`   | Feb 19, 2026 |
| Claude Opus 3     | `claude-3-opus-20240229`      | Jan 5, 2026 |
| Claude Sonnet 3.5 | `claude-3-5-sonnet-20241022`  | Oct 28, 2025 |
| Claude Sonnet 3.5 | `claude-3-5-sonnet-20240620`  | Oct 28, 2025 |
| Claude Sonnet 3   | `claude-3-sonnet-20240229`    | Jul 21, 2025 |
| Claude 2.1        | `claude-2.1`                  | Jul 21, 2025 |
| Claude 2.0        | `claude-2.0`                  | Jul 21, 2025 |

## Resolving User Requests

When a user asks for a model by name, use this table to find the correct model ID:

| User says...                              | Use this model ID              |
|-------------------------------------------|--------------------------------|
| "most powerful", "best", "fable"          | `claude-fable-5`               |
| "mythos"                                  | `claude-mythos-5` (invitation-only; warn about access) |
| "opus"                                    | `claude-opus-4-8`              |
| "opus 4.8"                                | `claude-opus-4-8`              |
| "opus 4.7"                                | `claude-opus-4-7`              |
| "opus 4.6"                                | `claude-opus-4-6`              |
| "opus 4.5"                                | `claude-opus-4-5`              |
| "opus 4.1"                                | `claude-opus-4-1` (deprecated — suggest `claude-opus-4-8`) |
| "sonnet", "balanced"                      | `claude-sonnet-5`              |
| "sonnet 5"                                | `claude-sonnet-5`              |
| "sonnet 4.6"                              | `claude-sonnet-4-6`            |
| "sonnet 4.5"                              | `claude-sonnet-4-5`            |
| "sonnet 3.7", "sonnet 3.5"                | Retired — suggest `claude-sonnet-5` |
| "haiku", "fast", "cheap"                  | `claude-haiku-4-5`             |
| "haiku 4.5"                               | `claude-haiku-4-5`             |
| "haiku 3.5", "haiku 3"                    | Retired/deprecated — suggest `claude-haiku-4-5` |
