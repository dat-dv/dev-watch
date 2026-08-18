#!/usr/bin/env bash

# devwatch.sh
# Ultra-lightweight macOS dev-session watcher.
# - Scans common dev commands
# - Groups by CWD + PGID
# - Highlights duplicate sessions in the same project
# - Shows likely origin (Terminal / Antigravity / Codex / ChatGPT / Other)
# - Shows listening ports when available
# - Shows total & per-session RAM/CPU usage
# - Flashes terminal title & sends bell on duplicates
#
# Usage:
#   chmod +x devwatch.sh
#   ./devwatch.sh
#   ./devwatch.sh 10   # refresh every 10s
#
# Press 'q' to quit, 'r' to refresh, or Ctrl+C.

set -u

INTERVAL="${1:-60}"

RED=$'\033[31;1m'
FLASH_RED=$'\033[5;31;1m'
YELLOW=$'\033[33;1m'
GREEN=$'\033[32;1m'
CYAN=$'\033[36;1m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

TMP_BASE="${TMPDIR:-/tmp}/devwatch.$$"
PS_FILE="${TMP_BASE}.ps"
PORTS_FILE="${TMP_BASE}.ports"
CWDS_FILE="${TMP_BASE}.cwds"

SAVED_STTY="$(stty -g 2>/dev/null || true)"

cleanup() {
  rm -f "$PS_FILE" "$PORTS_FILE" "$CWDS_FILE"
  # Restore terminal title & stty
  printf "\033]0;Terminal\007" 2>/dev/null || true
  if [ -n "${SAVED_STTY:-}" ]; then
    stty "$SAVED_STTY" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

get_self_usage() {
  ps -p $$ -o %cpu=,rss= 2>/dev/null | awk '{
    cpu=$1; rss=$2;
    if (rss < 1024) mem = rss " KB";
    else mem = sprintf("%.1f MB", rss/1024);
    printf "%s RAM · %.1f%% CPU", mem, cpu;
  }' || printf "N/A"
}

scan_and_render() {
  : > "$PS_FILE"
  : > "$PORTS_FILE"
  : > "$CWDS_FILE"

  # 1. Capture process snapshot
  ps -axo pid=,ppid=,pgid=,%cpu=,rss=,etime=,command= > "$PS_FILE"

  # 2. Capture listening ports
  lsof -nP -iTCP -sTCP:LISTEN -Fpcn 2>/dev/null > "$PORTS_FILE"

  # 3. Find candidate dev process PIDs for batch CWD query
  dev_pids="$(awk '
    function is_dev(cmd) {
      if (cmd ~ /(\/System\/|\/usr\/libexec\/|\/Applications\/.*Helper|tsserver\.js|eslintServer\.js|language-features)/) return 0;
      if (cmd ~ /(npm run |npm start|npx |pnpm |yarn |bun |next dev|next start|vite|tsx |tsx watch|ts-node|tsc --watch|tsc -w|nodemon|concurrently|turbo dev|webpack serve|nest start|react-scripts start|esbuild )/) return 1;
      return 0;
    }
    {
      pid = $1;
      $1=$2=$3=$4=$5=$6="";
      sub(/^[ \t]+/, "");
      if (is_dev($0)) {
        pids = pids (pids ? "," : "") pid;
      }
    }
    END { print pids }
  ' "$PS_FILE")"

  if [ -n "$dev_pids" ]; then
    lsof -a -p "$dev_pids" -d cwd -Fn 2>/dev/null > "$CWDS_FILE"
  fi

  clear
  self_stats="$(get_self_usage)"
  printf "${BOLD}DevWatch 🛡️${RESET}  ${DIM}refresh ${INTERVAL}s · [r] refresh · [q] quit · watcher: %s${RESET}\n\n" "$self_stats"

  awk -v home="$HOME" -v self_stats="$self_stats" \
      -v red="$RED" -v flash_red="$FLASH_RED" -v green="$GREEN" -v cyan="$CYAN" \
      -v bold="$BOLD" -v dim="$DIM" -v reset="$RESET" '
    function is_dev(cmd) {
      if (cmd ~ /(\/System\/|\/usr\/libexec\/|\/Applications\/.*Helper|tsserver\.js|eslintServer\.js|language-features)/) return 0;
      if (cmd ~ /(npm run |npm start|npx |pnpm |yarn |bun |next dev|next start|vite|tsx |tsx watch|ts-node|tsc --watch|tsc -w|nodemon|concurrently|turbo dev|webpack serve|nest start|react-scripts start|esbuild )/) return 1;
      return 0;
    }

    function shorten_path(p) {
      if (p == home) return "~";
      hp = home "/";
      if (index(p, hp) == 1) return "~/" substr(p, length(hp) + 1);
      return p;
    }

    function basename(p) {
      n = split(p, parts, "/");
      return parts[n];
    }

    # File 1: PS_FILE
    FILENAME ~ /\.ps$/ {
      pid = $1; ppid = $2; pgid = $3; cpu = $4; rss = $5; etime = $6;
      $1=$2=$3=$4=$5=$6="";
      sub(/^[ \t]+/, "");
      cmd = $0;

      pid_ppid[pid] = ppid;
      pid_pgid[pid] = pgid;
      pid_cpu[pid] = cpu;
      pid_rss[pid] = rss;
      pid_etime[pid] = etime;
      pid_cmd[pid] = cmd;
      all_pids[++p_cnt] = pid;
      next;
    }

    # File 2: PORTS_FILE
    FILENAME ~ /\.ports$/ {
      if ($0 ~ /^p/) {
        curr_port_pid = substr($0, 2);
      } else if ($0 ~ /^n/) {
        name = substr($0, 2);
        if (match(name, /:[0-9]+$/)) {
          port = substr(name, RSTART+1);
          g = pid_pgid[curr_port_pid];
          if (g != "") {
            if (!(g SUBSEP port in port_seen)) {
              port_seen[g SUBSEP port] = 1;
              ports_map[g] = ports_map[g] (ports_map[g] ? "," : "") port;
            }
          }
        }
      }
      next;
    }

    # File 3: CWDS_FILE
    FILENAME ~ /\.cwds$/ {
      if ($0 ~ /^p/) {
        curr_cwd_pid = substr($0, 2);
      } else if ($0 ~ /^n/) {
        cwd = substr($0, 2);
        pid_cwd[curr_cwd_pid] = cwd;
      }
      next;
    }

    END {
      for (i = 1; i <= p_cnt; i++) {
        pid = all_pids[i];
        cmd = pid_cmd[pid];
        if (!is_dev(cmd)) continue;

        cwd = pid_cwd[pid];
        if (cwd == "" || cwd ~ /^(\/System\/|\/usr\/|\/Library\/|\/Applications\/|\/private\/var\/)/) continue;

        # Origin lookup in memory
        curr = pid;
        depth = 0;
        origin = "Other";
        while (curr > 1 && (curr in pid_ppid) && depth++ < 20) {
          c = pid_cmd[curr];
          if (c ~ /(\/Terminal\.app\/|iTerm\.app|Warp\.app|ghostty|kitty|wezterm)/) { origin="Terminal"; break; }
          if (c ~ /Antigravity IDE/) { origin="Antigravity"; break; }
          if (c ~ /Codex/) { origin="Codex"; break; }
          if (c ~ /ChatGPT\.app/) { origin="ChatGPT"; break; }
          curr = pid_ppid[curr];
        }

        pgid = pid_pgid[pid];
        key = cwd SUBSEP pgid;

        if (!(key in sess_seen)) {
          sess_seen[key] = 1;
          sess_order[++sess_n] = key;
          sess_cwd[key] = cwd;
          sess_pgid[key] = pgid;
          sess_pid[key] = pid;
          sess_age[key] = pid_etime[pid];
          sess_origin[key] = origin;
          sess_cmd[key] = cmd;
        } else {
          if (pid == pgid) {
            sess_pid[key] = pid;
            sess_age[key] = pid_etime[pid];
            sess_origin[key] = origin;
            sess_cmd[key] = cmd;
          }
        }

        sess_cpu[key] += pid_cpu[pid];
        sess_rss[key] += pid_rss[pid];

        project_seen[cwd] = 1;
        project_sess_count[cwd SUBSEP pgid] = 1;
      }

      if (sess_n == 0) {
        printf "\033]0;✓ DevWatch (Clean)\007";
        printf "%s✓ No dev sessions detected.%s\n", green, reset;
        exit 0;
      }

      dup_projects = 0;
      for (c in project_seen) {
        cnt = 0;
        for (k in project_sess_count) {
          split(k, parts, SUBSEP);
          if (parts[1] == c) cnt++;
        }
        project_count[c] = cnt;
        if (cnt > 1) dup_projects++;
      }

      # Update Terminal Title & Bell on Duplicate
      if (dup_projects > 0) {
        printf "\033]0;⚠️ DUPLICATE (%d) - DevWatch\007", dup_projects;
        printf "\a"; # Terminal alert bell
      } else {
        printf "\033]0;✓ DevWatch (Clean)\007";
      }

      printf "%s%-24s %-12s %-8s %-8s %-8s %-10s %-10s %-12s %s%s\n", \
        bold, "PROJECT", "ORIGIN", "PGID", "PID", "CPU", "MEM", "AGE", "PORT", "COMMAND", reset;

      total_rss = 0;

      for (i = 1; i <= sess_n; i++) {
        key = sess_order[i];
        cwd = sess_cwd[key];
        pgid = sess_pgid[key];
        pid = sess_pid[key];
        origin = sess_origin[key];
        age = sess_age[key];
        cmd = sess_cmd[key];
        dup_cnt = project_count[cwd];

        p_name = basename(cwd);
        ports = ports_map[pgid];
        if (ports == "") ports = "-";

        if (dup_cnt > 1) {
          prefix = flash_red "⚠";
          suffix = "  " flash_red "DUPLICATE" reset;
        } else {
          prefix = green "✓";
          suffix = reset;
        }

        r = sess_rss[key];
        total_rss += r;

        if (r < 1024) mem_str = sprintf("%d KB", r);
        else if (r < 1048576) mem_str = sprintf("%.1f MB", r / 1024);
        else mem_str = sprintf("%.2f GB", r / 1048576);

        cpu_str = sprintf("%.1f%%", sess_cpu[key]);

        printf "%s %-22s %-12s %-8s %-8s %-8s %-10s %-10s %-12s %.80s%s\n", \
          prefix, p_name, origin, pgid, pid, cpu_str, mem_str, age, ports, cmd, suffix;

        printf "  %s%s%s\n", dim, shorten_path(cwd), reset;
      }

      printf "\n";

      if (total_rss > 0) {
        if (total_rss < 1024) total_mem = total_rss " KB";
        else if (total_rss < 1048576) total_mem = sprintf("%.1f MB", total_rss / 1024);
        else total_mem = sprintf("%.2f GB", total_rss / 1048576);

        printf "%s%s📊 Total Dev RAM: %s%s  %s(Watcher self: %s)%s\n", \
          cyan, bold, total_mem, reset, dim, self_stats, reset;
      }

      if (dup_projects > 0) {
        printf "%s%s⚠ %d project(s) have multiple dev sessions.%s\n", flash_red, bold, dup_projects, reset;
        printf "%sKill a whole session safely with: kill -- -PGID%s\n", dim, reset;
      } else {
        printf "%s✓ No duplicate dev sessions.%s\n", green, reset;
      }
    }
  ' "$PS_FILE" "$PORTS_FILE" "$CWDS_FILE"
}

while true; do
  scan_and_render

  stty -icanon -echo 2>/dev/null || true
  key=""
  read -t "$INTERVAL" -n 1 key 2>/dev/null || true
  stty "$SAVED_STTY" 2>/dev/null || true

  case "$key" in
    q|Q)
      exit 0
      ;;
  esac
done
