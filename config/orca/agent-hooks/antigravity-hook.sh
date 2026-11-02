#!/bin/sh
case "$ORCA_ANTIGRAVITY_EVENT" in
  Stop)
    printf '{"decision":""}\n'
    ;;
  PreToolUse)
    printf '{"decision":"ask"}\n'
    ;;
  *)
    printf "{}\n"
    ;;
esac
orca_hook_json_stdin_py='import codecs, json, os, select
text = ""
try:
    decoder = codecs.getincrementaldecoder("utf-8")("replace")
    timeout = 5.0
    while 1:
        if not select.select([0], [], [], timeout)[0]:
            text += decoder.decode(b"", True)
            break
        chunk = os.read(0, 65536)
        if not chunk:
            text += decoder.decode(b"", True)
            break
        timeout = 1.5
        text += decoder.decode(chunk)
        value = text.lstrip()
        if not value:
            continue
        try:
            end = json.JSONDecoder().raw_decode(value)[1]
        except ValueError:
            continue
        text = value[:end]
        break
except Exception:
    pass
try:
    data = text.encode("utf-8")
    written = 0
    while written < len(data):
        written += os.write(1, data[written:])
except Exception:
    pass'
payload=$({ [ -d "${HOME:-}" ] || unset HOME; }; command -p python3 -c "$orca_hook_json_stdin_py" 2>/dev/null || command -p python -c "$orca_hook_json_stdin_py" 2>/dev/null || { command -p cat 2>/dev/null || cat; })
if [ -z "$payload" ]; then
  payload='{}'
fi
spool_hook_event() {
  case "${ORCA_ANTIGRAVITY_EVENT:-}" in PreToolUse|PostToolUse|PostToolUseFailure) return 0 ;; esac
  [ -n "${ORCA_AGENT_HOOK_ENDPOINT:-}" ] || return 0
  [ -n "${ORCA_PANE_KEY:-}" ] || return 0
  [ -r "$ORCA_AGENT_HOOK_ENDPOINT" ] || return 0
  spool_base=${ORCA_AGENT_HOOK_ENDPOINT%/*}
  spool_dir="$spool_base/spool"
  mkdir -p "$spool_dir" 2>/dev/null || return 0
  chmod 700 "$spool_dir" 2>/dev/null || :
  spool_id=$(printf %s "${ORCA_PANE_KEY:-unknown}" | tail -c 36 | tr '/:' '__')
  spool_file="$spool_dir/pane-$spool_id.jsonl"
  if [ -f "$spool_file" ] && find "$spool_file" -mtime +7 -print -quit 2>/dev/null | grep -q .; then : > "$spool_file"; fi
  [ -f "$spool_file" ] || : > "$spool_file"
  spool_size=$(wc -c < "$spool_file" 2>/dev/null || printf 0)
  [ "$spool_size" -lt 5242880 ] || return 0
  spool_now=$(date +%s 2>/dev/null || printf 0)
  spool_now=$((spool_now * 1000))
  spool_json_escape() { printf %s "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/[[:cntrl:]]/ /g'; }
  { printf '\n{"hookEventName":"%s","paneKey":"%s","tabId":"%s","worktreeId":"%s","env":"%s","version":"%s","launchToken":"%s","source":"%s","receivedAt":%s,"agentProcess":"%s","payload":%s}\n' "$(spool_json_escape "${ORCA_ANTIGRAVITY_EVENT:-}")" "$(spool_json_escape "${ORCA_PANE_KEY:-}")" "$(spool_json_escape "${ORCA_TAB_ID:-}")" "$(spool_json_escape "${ORCA_WORKTREE_ID:-}")" "$(spool_json_escape "${ORCA_AGENT_HOOK_ENV:-}")" "$(spool_json_escape "${ORCA_AGENT_HOOK_VERSION:-}")" "$(spool_json_escape "${ORCA_AGENT_LAUNCH_TOKEN:-}")" "$(spool_json_escape "antigravity")" "$spool_now" "$(spool_json_escape "${orca_agent_process:-}")" "$payload"; } >> "$spool_file" 2>/dev/null || :
  chmod 600 "$spool_file" 2>/dev/null || :
}
if [ -n "$ORCA_AGENT_HOOK_ENDPOINT" ] && [ -r "$ORCA_AGENT_HOOK_ENDPOINT" ]; then
  . "$ORCA_AGENT_HOOK_ENDPOINT" 2>/dev/null || :
fi
if [ -z "$ORCA_AGENT_HOOK_PORT" ] || [ -z "$ORCA_AGENT_HOOK_TOKEN" ] || [ -z "$ORCA_PANE_KEY" ]; then
  spool_hook_event
  exit 0
fi
printf '%s' "$payload" | LC_ALL= LC_NUMERIC=C curl -sS -X POST "http://127.0.0.1:${ORCA_AGENT_HOOK_PORT}/hook/antigravity" \
  --connect-timeout 0.5 --max-time 1.5 \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Orca-Agent-Hook-Token: ${ORCA_AGENT_HOOK_TOKEN}" \
  --data-urlencode "paneKey=${ORCA_PANE_KEY}" \
  --data-urlencode "tabId=${ORCA_TAB_ID}" \
  --data-urlencode "launchToken=${ORCA_AGENT_LAUNCH_TOKEN}" \
  --data-urlencode "worktreeId=${ORCA_WORKTREE_ID}" \
  --data-urlencode "env=${ORCA_AGENT_HOOK_ENV}" \
  --data-urlencode "version=${ORCA_AGENT_HOOK_VERSION}" \
  --data-urlencode "hook_event_name=${ORCA_ANTIGRAVITY_EVENT}" \
  --data-urlencode "payload@-" >/dev/null 2>&1 || spool_hook_event
exit 0
