#!/bin/sh
printf "{}\n"
: "${ORCA_PANE_KEY:=${ORCA_AGENT_PANE:-}}"
: "${ORCA_AGENT_LAUNCH_TOKEN:=${ORCA_AGENT_LAUNCH:-}}"
export ORCA_PANE_KEY ORCA_AGENT_LAUNCH_TOKEN
payload=$({ command -p cat 2>/dev/null || cat; })
if [ -z "$payload" ]; then
  exit 0
fi
if [ -n "$GROK_HOOK_EVENT" ]; then
  exit 0
fi
if [ -n "$CURSOR_VERSION" ] && [ -n "$CURSOR_PROJECT_DIR" ]; then
  exit 0
fi
spool_hook_event() {
  case "$payload" in *'"PreToolUse"'*|*'"PostToolUse"'*|*'"PostToolUseFailure"'*) return 0 ;; esac
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
  { printf '\n{"paneKey":"%s","tabId":"%s","worktreeId":"%s","env":"%s","version":"%s","launchToken":"%s","source":"%s","receivedAt":%s,"agentProcess":"%s","payload":%s}\n' "$(spool_json_escape "${ORCA_PANE_KEY:-}")" "$(spool_json_escape "${ORCA_TAB_ID:-}")" "$(spool_json_escape "${ORCA_WORKTREE_ID:-}")" "$(spool_json_escape "${ORCA_AGENT_HOOK_ENV:-}")" "$(spool_json_escape "${ORCA_AGENT_HOOK_VERSION:-}")" "$(spool_json_escape "${ORCA_AGENT_LAUNCH_TOKEN:-}")" "$(spool_json_escape "claude")" "$spool_now" "$(spool_json_escape "${orca_agent_process:-}")" "$payload"; } >> "$spool_file" 2>/dev/null || :
  chmod 600 "$spool_file" 2>/dev/null || :
}
if [ -n "$DEVIN_PROJECT_DIR" ]; then
  exit 0
fi
if [ -n "$CLAUDE_JOB_DIR" ]; then
  exit 0
fi
orca_agent_process=
[ -z "${ORCA_PANE_KEY:-}" ] || case "${ORCA_HOOK_AGENT_PID:-}" in ""|*[!0-9]*) ;; *)
  if [ -r "/proc/$ORCA_HOOK_AGENT_PID/stat" ]; then
    orca_agent_stat=$(cat "/proc/$ORCA_HOOK_AGENT_PID/stat" 2>/dev/null) || orca_agent_stat=
    orca_agent_boot=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null) || orca_agent_boot=
    orca_agent_fields=${orca_agent_stat##*) }
    orca_agent_start=$(printf "%s" "$orca_agent_fields" | awk '{print $20}')
    case "$orca_agent_start" in ""|*[!0-9]*) ;; *)
      [ -z "$orca_agent_boot" ] || orca_agent_process=$(printf '{"pid":%s,"platform":"linux","startTime":"%s:%s"}' "$ORCA_HOOK_AGENT_PID" "$orca_agent_boot" "$orca_agent_start") ;; esac
  elif [ "$(uname -s 2>/dev/null)" = Darwin ]; then
    orca_agent_start=$(TZ=UTC0 LC_ALL=C /bin/ps -p "$ORCA_HOOK_AGENT_PID" -o lstart= 2>/dev/null | sed 's/^ *//;s/ *$//')
    [ -z "$orca_agent_start" ] || orca_agent_process=$(printf '{"pid":%s,"platform":"darwin","startTime":"%s"}' "$ORCA_HOOK_AGENT_PID" "$orca_agent_start")
  fi ;;
esac
if [ -n "$ORCA_AGENT_HOOK_ENDPOINT" ] && [ -r "$ORCA_AGENT_HOOK_ENDPOINT" ]; then
  unset ORCA_AGENT_HOOK_TRANSPORT
  . "$ORCA_AGENT_HOOK_ENDPOINT" 2>/dev/null || :
fi
if [ -z "$ORCA_AGENT_HOOK_PORT" ] || [ -z "$ORCA_AGENT_HOOK_TOKEN" ] || [ -z "$ORCA_PANE_KEY" ]; then
  spool_hook_event
  exit 0
fi
if [ "${ORCA_AGENT_HOOK_TRANSPORT:-}" = "raw-json-v1" ] && command -v base64 >/dev/null 2>&1 && command -v tr >/dev/null 2>&1; then
  orca_hook_metadata=$(printf '%s\037%s\037%s\037%s\037%s\037%s' "$ORCA_PANE_KEY" "$ORCA_TAB_ID" "$ORCA_AGENT_LAUNCH_TOKEN" "$ORCA_WORKTREE_ID" "$ORCA_AGENT_HOOK_ENV" "$ORCA_AGENT_HOOK_VERSION" | base64 | tr -d '\n') && \
  [ -n "$orca_hook_metadata" ] && \
  printf '%s' "$payload" | LC_ALL= LC_NUMERIC=C curl -sS -X POST "http://127.0.0.1:${ORCA_AGENT_HOOK_PORT}/hook/claude" \
    --connect-timeout "${connect_timeout:-0.5}" --max-time "${max_time:-1.5}" \
    --noproxy "127.0.0.1" \
    -H "Content-Type: application/json" \
    -H "X-Orca-Agent-Hook-Token: ${ORCA_AGENT_HOOK_TOKEN}" \
    -H "X-Orca-Agent-Hook-Meta-Encoding: base64" \
    -H "X-Orca-Agent-Hook-Meta: ${orca_hook_metadata}" \
    -H "X-Orca-Agent-Process: ${orca_agent_process:-}" \
    --data-binary @-
else
  printf '%s' "$payload" | LC_ALL= LC_NUMERIC=C curl -sS -X POST "http://127.0.0.1:${ORCA_AGENT_HOOK_PORT}/hook/claude" \
    --connect-timeout "${connect_timeout:-0.5}" --max-time "${max_time:-1.5}" \
    --noproxy "127.0.0.1" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "X-Orca-Agent-Hook-Token: ${ORCA_AGENT_HOOK_TOKEN}" \
    --data-urlencode "paneKey=${ORCA_PANE_KEY}" \
    --data-urlencode "tabId=${ORCA_TAB_ID}" \
    --data-urlencode "launchToken=${ORCA_AGENT_LAUNCH_TOKEN}" \
    --data-urlencode "worktreeId=${ORCA_WORKTREE_ID}" \
    --data-urlencode "env=${ORCA_AGENT_HOOK_ENV}" \
    --data-urlencode "version=${ORCA_AGENT_HOOK_VERSION}" \
    --data-urlencode "agentProcess=${orca_agent_process:-}" \
    --data-urlencode "payload@-"
fi >/dev/null 2>&1 || spool_hook_event
exit 0
