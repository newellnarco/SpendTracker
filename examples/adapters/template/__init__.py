"""Template pull adapter. Copy with `st adapter new <id> --mechanism pull` and fill in the TODOs.

CONTEXT: docs/01-architecture/ADAPTER-SPEC.md defines the contract this file must satisfy.
"""
from __future__ import annotations

import hashlib
from datetime import datetime, timezone

from spendtracker.core.api import (
    Adapter,
    AdapterInfo,
    Context,
    Cursor,
    Health,
    RawBatch,
    UsageEvent,
)


class ExampleVendorAdapter(Adapter):
    id = "example_vendor"

    def discover(self, ctx: Context) -> AdapterInfo:
        return AdapterInfo.from_manifest(self.manifest, configured=bool(ctx.config.get("api_key_env")))

    def collect(self, ctx: Context, cursor: Cursor | None) -> RawBatch:
        # TODO: call the vendor usage endpoint from `cursor` (a date) to today.
        since = cursor.value if cursor else ctx.now().date().isoformat()
        resp = ctx.http.get(
            f"{ctx.config.get('base_url', 'https://api.example.com')}/v1/usage",
            params={"since": since},
            headers={"Authorization": f"Bearer {ctx.secret(ctx.config['api_key_env'])}"},
        )
        resp.raise_for_status()
        payload = resp.json()
        # Cursor = last complete day; re-fetching the same day is safe because source_ref is stable.
        next_cursor = Cursor(value=payload.get("last_complete_day", since))
        return RawBatch(payloads=[payload], next_cursor=next_cursor)

    def normalize(self, ctx: Context, raw: RawBatch) -> list[UsageEvent]:
        events: list[UsageEvent] = []
        for payload in raw.payloads:
            for line in payload.get("lines", []):
                # TODO: map vendor fields. Keep source_ref stable: a vendor id, else a hash of the line.
                ref = line.get("id") or hashlib.sha256(
                    f"{line['day']}|{line['model']}|{line['input_tokens']}|{line['output_tokens']}".encode()
                ).hexdigest()
                at = datetime.fromisoformat(line["day"]).replace(tzinfo=timezone.utc)
                base = dict(
                    app_id="example_vendor",
                    occurred_at=at,
                    model=line["model"],
                    source="api",
                    source_ref=ref,
                    account_key=f"example_vendor:{payload.get('account_id', 'default')}",
                )
                events.append(UsageEvent(measure_id="token.input", quantity=line["input_tokens"], **base))
                events.append(UsageEvent(measure_id="token.output", quantity=line["output_tokens"], **base))
                events.append(UsageEvent(measure_id="request.count", quantity=line.get("requests", 1), **base))
                if "cost_usd" in line:
                    events.append(UsageEvent(measure_id="cost.reported.usd", quantity=line["cost_usd"], **base))
        return events

    def health(self, ctx: Context) -> Health:
        if not ctx.config.get("api_key_env") or not ctx.secret(ctx.config["api_key_env"]):
            return Health.warn("API key env var not set")
        return Health.ok()
