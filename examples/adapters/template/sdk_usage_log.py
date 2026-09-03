"""Ten-line usage logger for applications calling the Claude API directly (adapter `sdk_usage_log`).

Wrap your existing client call; this writes one spool envelope per response. No content is recorded.
"""
import json, os, time, uuid
from pathlib import Path

SPOOL = Path(os.environ.get("SPENDTRACKER_SPOOL", Path.home() / ".spendtracker" / "spool"))


def log_usage(response, app_id: str = "claude_api", project_key: str | None = None) -> None:
    u = response.usage
    base = {
        "v": 1, "adapter": "sdk_usage_log", "app": app_id, "source": "api",
        "occurred_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "model": response.model, "source_ref": response.id, "project_key": project_key, "attrs": {},
    }
    measures = {
        "token.input": u.input_tokens, "token.output": u.output_tokens,
        "token.cache_read": getattr(u, "cache_read_input_tokens", 0) or 0,
        "token.cache_write": getattr(u, "cache_creation_input_tokens", 0) or 0,
        "request.count": 1,
    }
    SPOOL.mkdir(parents=True, exist_ok=True)
    tmp = SPOOL / f".{uuid.uuid4()}.tmp"
    tmp.write_text("\n".join(json.dumps({**base, "measure": m, "quantity": q}) for m, q in measures.items()))
    tmp.rename(SPOOL / f"{int(time.time()*1000)}-{uuid.uuid4().hex[:8]}.jsonl")
