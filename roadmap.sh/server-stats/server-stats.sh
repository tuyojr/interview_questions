#!/usr/bin/env bash
set -u

print_header() {
  echo "Server Stats"
  echo "Host: $(hostname)"
  echo "Time: $(date)"
  echo
}

print_os_uptime_load() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "OS: ${PRETTY_NAME}"
  else
    echo "OS: $(uname -sr)"
  fi

  if uptime -p >/dev/null 2>&1; then
    echo "Uptime: $(uptime -p | sed 's/^up //')"
  else
    echo "Uptime: $(uptime)"
  fi

  if [ -r /proc/loadavg ]; then
    echo "Load Average (1m 5m 15m): $(awk '{print $1" "$2" "$3}' /proc/loadavg)"
  else
    echo "Load Average: N/A"
  fi
  echo
}

print_cpu() {
  if [ -r /proc/stat ]; then
    usage=$(awk '/^cpu /{non=$2+$3+$4+$7+$8+$9; total=non+$5+$6; printf "%.1f", (non/total)*100}' /proc/stat)
    echo "Total CPU usage: ${usage}%"
  else
    echo "Total CPU usage: N/A"
  fi
  echo
}

print_memory() {
  if [ -r /proc/meminfo ]; then
    total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    [ -z "$avail" ] && avail=$(awk '/MemFree/ {print $2}' /proc/meminfo)
    used=$((total - avail))
    used_pct=$(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f", (u/t)*100 }')
    free_pct=$(awk -v a="$avail" -v t="$total" 'BEGIN { printf "%.1f", (a/t)*100 }')
    echo "Memory Usage (KB):"
    echo "  Used: $used (${used_pct}%)"
    echo "  Free: $avail (${free_pct}%)"
    echo "  Total: $total"
  else
    echo "Memory Usage: N/A"
  fi
  echo
}

print_disk() {
  if command -v df >/dev/null 2>&1; then
    read -r total used avail <<<"$(df -Pk -x tmpfs -x devtmpfs | awk 'NR>1 {t+=$2; u+=$3; a+=$4} END {print t" "u" "a}')"
    used_pct=$(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f", (u/t)*100 }')
    free_pct=$(awk -v a="$avail" -v t="$total" 'BEGIN { printf "%.1f", (a/t)*100 }')
    echo "Disk Usage (KB, excluding tmpfs/devtmpfs):"
    echo "  Used: $used (${used_pct}%)"
    echo "  Free: $avail (${free_pct}%)"
    echo "  Total: $total"
  else
    echo "Disk Usage: N/A"
  fi
  echo
}

print_top_processes() {
  if command -v ps >/dev/null 2>&1; then
    echo "Top 5 Processes by CPU Usage:"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
    echo
    echo "Top 5 Processes by Memory Usage:"
    ps -eo pid,comm,%mem --sort=-%mem | head -n 6
  else
    echo "Top processes: N/A (ps not found)"
  fi
  echo
}

print_users_and_failures() {
  if command -v who >/dev/null 2>&1; then
    users=$(who)
    if [ -n "$users" ]; then
      echo "Logged In Users: $(echo "$users" | wc -l)"
      echo "$users"
    else
      echo "Logged In Users: 0"
    fi
  else
    echo "Logged In Users: N/A"
  fi
  echo

  if [ -r /var/log/auth.log ]; then
    log=/var/log/auth.log
  elif [ -r /var/log/secure ]; then
    log=/var/log/secure
  else
    echo "Failed Login Attempts: N/A (auth log not readable)"
    return
  fi

  count=$(grep -c "Failed password" "$log" 2>/dev/null || true)
  echo "Failed Login Attempts (Failed password): $count"
  if [ "$count" -gt 0 ]; then
    echo "Recent failed attempts (last 5):"
    grep "Failed password" "$log" | tail -n 5
  fi
}

print_header
print_os_uptime_load
print_cpu
print_memory
print_disk
print_top_processes
print_users_and_failures
