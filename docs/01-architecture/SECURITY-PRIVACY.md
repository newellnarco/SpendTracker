# Security and privacy

## Threat model

Local-first tooling on developer machines that holds usage metadata, vendor tokens (by reference)
and, optionally, raw API payloads. The main risks are leaking tokens into the database or exports,
leaking prompt or code content through attrs or raw payloads, and exposing the local UI to the
network.

## Rules

| Area | Rule |
| --- | --- |
| Tokens | `config.toml` stores the **name** of an environment variable, never the value. `st doctor` warns if a value looks like a token. Exports and the DB never contain tokens; CI runs a secret scan on every rollup PR. |
| Prompts and code | Never stored. Claude Code hooks read only ids, counts and timestamps. `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_ASSISTANT_RESPONSES`, `OTEL_LOG_TOOL_CONTENT` and `OTEL_LOG_RAW_API_BODIES` must stay unset for the SpendTracker exporter; the receiver drops `prompt`, `response`, `body`, `tool_input` attributes if they arrive. |
| Raw payload archive | Off by default. When on, it holds vendor billing lines and OTel records already stripped of content attributes. Not exported. |
| Transcripts | Parsed in place; only usage numbers are stored. |
| Identity | Hostnames and emails are stored hashed unless the node opts in. Export `standard` redaction replaces actor with the node's user handle. |
| Network | The UI and OTLP receiver bind to `127.0.0.1` only. `--host 0.0.0.0` requires `--allow-remote` and prints a warning; there is no authentication layer, so remote exposure is for trusted networks with a reverse proxy in front. |
| Rollup repo | Private repository. Branch protection on `main`; CI validation required. Redaction minimums per node enforced by CI. |
| Dependencies | Pinned lockfile; `pip-audit` in CI; no runtime downloads (Chart.js and fonts vendored). |
| Hooks | Scripts are shipped with a checksum; `st hooks install` writes them to `~/.spendtracker/hooks/` and prints the diff to any existing file before overwriting. |
| MCP proxy | Forwards JSON-RPC byte-for-byte; records method names, tool names, sizes and latency; never records arguments or results. |

## Data classification

| Data | Class | Leaves the machine? |
| --- | --- | --- |
| Usage counts, timestamps, model names, SKUs | internal | yes, in exports |
| Project keys (repo remotes) | internal | yes (`standard`), org-only (`minimal`) |
| Session ids | internal | yes (`standard`), no (`minimal`) |
| Actor identity | personal | handle only |
| Tokens | secret | never |
| Prompt/response/tool content | confidential | never stored |
