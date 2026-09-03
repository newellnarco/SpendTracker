# Vendor signals verified during the design phase

Date: 2026-09-02  Author: design session
Verified against: Claude Code monitoring and hooks reference (code.claude.com/docs), GitHub REST
billing usage and Copilot metrics reference (docs.github.com), GitHub Copilot billing change
announcement (github.blog), CodeRabbit pricing summaries (third-party, 2026), Claude platform pricing
as cached in the Claude API reference on 2026-06-24.

## Findings

### Claude Code
- Telemetry is enabled with `CLAUDE_CODE_ENABLE_TELEMETRY=1`; exporters `otlp`, `prometheus`,
  `console`; protocol `grpc`, `http/json`, `http/protobuf`.
- Metrics: `claude_code.cost.usage` (USD), `claude_code.token.usage` (type: input/output/cacheRead/
  cacheCreation), `claude_code.session.count`, `claude_code.active_time.total` (s),
  `claude_code.lines_of_code.count`, `claude_code.commit.count`, `claude_code.pull_request.count`,
  `claude_code.code_edit_tool.decision`. Attributes include `model`, `query_source`, `speed`,
  `effort`, `agent.name`, `skill.name`, `plugin.name`, `mcp_server.name`, `mcp_tool.name`.
- Events (logs): `claude_code.api_request` with `cost_usd`, `cost_usd_micros`, `duration_ms`,
  `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_creation_tokens`, `request_id`;
  `claude_code.tool_result` with `tool_name`, `tool_use_id`, `success`, `duration_ms`,
  `mcp_server_name`, `mcp_tool_name`; `claude_code.api_error`; `claude_code.mcp_server_connection`.
- Standard attributes: `session.id`, `user.id`, `user.account_uuid`, `organization.id`,
  `user.email` (OAuth), plus `OTEL_RESOURCE_ATTRIBUTES`.
- Hooks: all hooks get `session_id`, `prompt_id`, `transcript_path`, `cwd`, `permission_mode`,
  `effort`, `hook_event_name`, `agent_id`, `agent_type`. `PostToolUse` adds `tool_name`,
  `tool_input`, `tool_use_id`, `tool_output`, `execution_time_ms`. `Stop` adds `turn_number`,
  `stop_reason`. `SessionStart` adds `model`, `session_start_reason`. `SessionEnd` adds
  `session_end_reason`, `turn_count`. Matchers accept regex such as `mcp__.*`. Command hooks
  support `async: true` and `timeout`.

### GitHub billing
- Usage report endpoints: `GET /users/{username}/settings/billing/usage` and
  `GET /organizations/{org}/settings/billing/usage` with `year`, `month`, `day`; `/usage/summary`
  adds `repository`, `product`, `sku` filters. Items carry `product`, `sku`, `unitType`,
  `pricePerUnit`, `grossQuantity`, `grossAmount`, `discountQuantity`, `discountAmount`,
  `netQuantity`, `netAmount`, and for the standard endpoint `date`, `quantity`, `repositoryName`.
- Copilot billing endpoints: `.../settings/billing/ai_credit/usage` and
  `.../settings/billing/premium_request/usage` (both user and org), filters `year`, `month`, `day`,
  `model`, `product`, and `user` for orgs. Items include `model`.
- Copilot metrics reports (org and enterprise) return signed `download_links` for 1-day and 28-day
  reports at organization, repos, users and user-teams grain; org scope `read:org`.

### Copilot billing model
- From 2026-06-01 Copilot bills by usage: plans include monthly GitHub AI Credits; usage is metered
  in tokens by model at listed API rates; additional usage is purchasable on paid plans. Before that,
  premium requests with per-model multipliers. Both regimes need modelling for history.

### CodeRabbit
- Per-seat pricing (developers who open PRs). Pro about $24/user/month annual or $30 monthly;
  Pro Plus about $48/user/month with a cap on reviews per developer; Enterprise custom. No public
  usage API found; reviews are visible on GitHub as `coderabbitai[bot]` activity.

### GitHub Actions
- Billed per minute, rounded up per job; Linux from $0.006/min, macOS up to $0.062/min; a proposed
  self-hosted runner platform charge was postponed. Free minute allowances appear as discounts.

### Anthropic
- Admin API usage report `GET /v1/organizations/usage_report/messages` (group_by model,
  api_key_id, workspace_id, service_tier, context_window; `bucket_width=1d`, up to 31 buckets per
  page) and cost report `GET /v1/organizations/cost_report` (USD as decimal strings in cents,
  `group_by[]=description`). Admin API keys only; not for individual accounts; raw HTTP, not in SDKs.
- Token pricing (first-party, cached 2026-06-24): Fable 5.1 $10/$50 per MTok, Opus 5 $5/$25,
  Sonnet 5 $2/$10, Haiku 4.5 $1/$5; cache read 0.1× input (Fable 5.1 cache read $0.25/MTok);
  cache write 1.25× (5 min) or 2× (1 h); batch 50 % off.

## Surprises
- Copilot's unit changed mid-2026 (premium requests → AI credits and tokens). Rate cards and
  measures must be effective-dated; the design handles this with two measures and dated cards.
- Copilot metrics are report downloads, not inline JSON.
- Claude Code hooks expose `execution_time_ms` on `PostToolUse`, which gives MCP latency without OTel.

## What this changes
- COLLECTORS.md written from these findings.
- Measures `copilot.ai_credit` and `copilot.premium_request` both registered.
- Open question Q-3 (CodeRabbit usage source) recorded in CONTEXT.md.
