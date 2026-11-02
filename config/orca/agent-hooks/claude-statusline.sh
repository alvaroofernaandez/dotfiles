#!/bin/sh
payload=
while IFS= read -r orca_statusline_line || [ -n "$orca_statusline_line" ]; do
  payload="${payload}${orca_statusline_line}
"
done
payload=${payload%?}
if [ -z "$payload" ]; then
  exit 0
fi
if [ -n "$CLAUDE_JOB_DIR" ]; then
  exit 0
fi
case "$payload" in
  *'"rate_limits"'*) ;;
  *) exit 0 ;;
esac
if [ -n "$ORCA_AGENT_HOOK_ENDPOINT" ] && [ -r "$ORCA_AGENT_HOOK_ENDPOINT" ]; then
  . "$ORCA_AGENT_HOOK_ENDPOINT" 2>/dev/null || :
fi
if [ -z "$ORCA_AGENT_HOOK_PORT" ] || [ -z "$ORCA_AGENT_HOOK_TOKEN" ] || [ -z "$ORCA_PANE_KEY" ]; then
  exit 0
fi
orca_statusline_pane_id=${ORCA_PANE_KEY##*:}
case "$orca_statusline_pane_id" in
  ''|*[!0-9]*) ;;
  *)
    orca_statusline_tab_id=${ORCA_PANE_KEY%:*}
    case "$orca_statusline_tab_id" in
      ''|*[!A-Za-z0-9._-]*) ;;
      *) orca_statusline_pane_id="${orca_statusline_tab_id}_${orca_statusline_pane_id}" ;;
    esac
    ;;
esac
orca_statusline_stamp="${TMPDIR:-/tmp}/orca-claude-statusline-last-${orca_statusline_pane_id}"
orca_statusline_now=
case "$payload" in
  *'"total_duration_ms"'*)
    orca_statusline_duration=${payload#*'"total_duration_ms"'}
    orca_statusline_duration=${orca_statusline_duration#*:}
    orca_statusline_duration=${orca_statusline_duration#"${orca_statusline_duration%%[![:space:]]*}"}
    orca_statusline_duration=${orca_statusline_duration%%[!0-9]*}
    case "$orca_statusline_duration" in
      0|[1-9]|[1-9][0-9]*)
        if [ "${#orca_statusline_duration}" -le 15 ]; then
          orca_statusline_now=$((orca_statusline_duration / 1000))
        fi
        ;;
    esac
    ;;
esac
if [ -z "$orca_statusline_now" ]; then
  orca_statusline_now=$(date +%s 2>/dev/null) || orca_statusline_now=
fi
case "$orca_statusline_now" in 0|[1-9]|[1-9][0-9]*) ;; *) orca_statusline_now= ;; esac
if [ -n "$orca_statusline_now" ] && [ -f "$orca_statusline_stamp" ]; then
  orca_statusline_last=
  IFS= read -r orca_statusline_last <"$orca_statusline_stamp" 2>/dev/null || :
  case "$orca_statusline_last" in 0|[1-9]|[1-9][0-9]*) ;; *) orca_statusline_last= ;; esac
  if [ "${#orca_statusline_last}" -gt 15 ]; then orca_statusline_last=; fi
  if [ -n "$orca_statusline_last" ]; then
    orca_statusline_elapsed=$((orca_statusline_now - orca_statusline_last))
    if [ "$orca_statusline_elapsed" -ge 0 ] && [ "$orca_statusline_elapsed" -lt 15 ]; then
      exit 0
    fi
  fi
fi
if [ -n "$orca_statusline_now" ]; then
  printf '%s' "$orca_statusline_now" >"$orca_statusline_stamp" 2>/dev/null || :
fi
printf '%s' "$payload" | LC_ALL= LC_NUMERIC=C curl -sS -X POST "http://127.0.0.1:${ORCA_AGENT_HOOK_PORT}/statusline/claude" \
  --connect-timeout 0.5 --max-time 1.5 \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Orca-Agent-Hook-Token: ${ORCA_AGENT_HOOK_TOKEN}" \
  --data-urlencode "paneKey=${ORCA_PANE_KEY}" \
  --data-urlencode "configDir=${CLAUDE_CONFIG_DIR}" \
  --data-urlencode "env=${ORCA_AGENT_HOOK_ENV}" \
  --data-urlencode "version=${ORCA_AGENT_HOOK_VERSION}" \
  --data-urlencode "payload@-" >/dev/null 2>&1 || true
exit 0
