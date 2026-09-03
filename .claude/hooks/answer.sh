#!/usr/bin/env bash
# Fable only: answer a question in place. Usage:
#   .claude/hooks/answer.sh --session <sid> Q-id "answer text" [--needs-human]
set -u
. "$(dirname "$0")/lib.sh"
sid=""; nh=0; args=()
while [ $# -gt 0 ]; do case "$1" in --session) sid="$2"; shift 2;; --needs-human) nh=1; shift;; *) args+=("$1"); shift;; esac; done
[ -z "$sid" ] && sid="$(cat "$ST_STATE_DIR/current-session" 2>/dev/null || echo unknown)"
id="${args[0]:-}"; text="${args[1]:-}"
[ -z "$id" ] || [ -z "$text" ] && { echo "usage: answer.sh --session <sid> Q-id \"answer\" [--needs-human]" >&2; exit 1; }
role="$(st_role "$sid")"
[ "$role" = "fable" ] || { echo "only the Fable session answers questions (session $sid is $role)" >&2; exit 1; }
qfile="$ST_ROOT/$(st_policy '.questions_file')"
grep -q "^### $id " "$qfile" || { echo "$id not found in $qfile" >&2; exit 1; }
status=$([ $nh = 1 ] && echo needs-human || echo answered)
model="$(st_state_get "$sid" model)"
python3 - "$qfile" "$id" "$status" "$text" "$(st_now)" "$sid" "${model:-fable}" <<'PY'
import sys,re
path,qid,status,text,now,sid,model=sys.argv[1:]
s=open(path).read()
start=s.index(f"### {qid} ")
end=s.find("\n### Q-",start+1); end=len(s) if end==-1 else end
block=s[start:end]
block=re.sub(r"^### (Q-\S+) · \S+", rf"### \1 · {status}", block, count=1, flags=re.M)
block=re.sub(r"^- Status: .*$", f"- Status: {status}", block, count=1, flags=re.M)
ans=f"- Answer (Fable): {text}\n- Answered: {now} · session `{sid}` · model `{model}`"
block=re.sub(r"^- Answer \(Fable\): .*$", ans, block, count=1, flags=re.M)
open(path,"w").write(s[:start]+block+s[end:])
PY
echo "$id -> $status"
