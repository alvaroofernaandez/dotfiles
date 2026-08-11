#!/usr/bin/env bash
# tmux status-right: CPU load and memory usage.
#
# This runs on every status refresh, so it is built to be cheap: three sysctl
# keys in a single call, one vm_stat, one awk. No `top` (208ms, it samples the
# whole process table) and no python interpreter start (29ms).
#
# CPU is derived from the 1-minute load average rather than sampled utilisation.
# Sampling utilisation requires two readings separated by a sleep, which is what
# makes the usual implementations cost seconds per refresh.
set -uo pipefail

sysctl_out="$(sysctl -n vm.loadavg hw.logicalcpu hw.memsize 2>/dev/null)"
vm_out="$(vm_stat 2>/dev/null)"

printf '%s\n---\n%s\n' "$sysctl_out" "$vm_out" | awk '
  BEGIN { section = 0; page = 4096; load = 0; ncpu = 1; total = 0 }

  /^---$/ { section = 1; next }

  section == 0 && /^\{/ {
    gsub(/[{}]/, "")
    load = $1 + 0
    next
  }
  section == 0 && NF == 1 && total == 0 && ncpu_set == 1 { total = $1 + 0; next }
  section == 0 && NF == 1 && ncpu_set != 1 { ncpu = $1 + 0; ncpu_set = 1; next }

  section == 1 && /page size of/ {
    for (i = 1; i <= NF; i++) if ($i == "of") { page = $(i + 1) + 0; break }
    next
  }
  section == 1 && /^Pages active/                 { gsub(/\./, ""); active = $NF + 0 }
  section == 1 && /^Pages wired down/             { gsub(/\./, ""); wired  = $NF + 0 }
  section == 1 && /^Pages occupied by compressor/ { gsub(/\./, ""); comp   = $NF + 0 }

  END {
    if (ncpu <= 0) ncpu = 1
    cpu = load / ncpu * 100
    if (cpu > 100) cpu = 100
    if (cpu < 0) cpu = 0

    used_bytes = (active + wired + comp) * page
    gb = 1073741824
    used = used_bytes / gb
    tot  = total / gb
    if (tot <= 0) tot = used
    if (used > tot) used = tot

    printf "%s%s %s %.1f%%%s %s %s %.1f/%.1fG #[default]",
      bold(), "CPU", bar(cpu), cpu, "",
      sep("RAM"), bar(tot > 0 ? used / tot * 100 : 0), used, tot
  }

  function colour(pct) {
    return pct < 50 ? "#[fg=colour46]" : (pct < 80 ? "#[fg=colour226]" : "#[fg=colour196]")
  }
  function bar(pct,   n, i, s) {
    n = int(pct / 100 * 12 + 0.5)
    if (n > 12) n = 12
    if (n < 0) n = 0
    s = colour(pct)
    for (i = 0; i < 12; i++) s = s (i < n ? "#" : "-")
    return s
  }
  function bold() { return "#[fg=colour45,bold]" }
  function sep(label) { return "#[fg=colour45,bold]" label }
'
printf '\n'
