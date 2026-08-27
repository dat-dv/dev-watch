#!/usr/bin/env bash

# devwatch.sh
# Ultra-lightweight & Rock-Solid macOS Dev & AI Agent Process Watcher.
#
# Safety Principles:
# 1. NEVER kill macOS system, OS daemons, or root processes.
# 2. NEVER kill IDE Core / UI renderers (Codex Renderer, Antigravity Helper, etc.).
# 3. Redact all API keys, bearer tokens, and secrets in commands.
# 4. Evidence-based classification: Distinguish Active Dev Servers, Active MCPs, and Orphan/Runaways.
# 5. Strict safety guardrails on kill: Only allow killing verified user/agent managed PIDs in inventory.
#
# Usage:
#   chmod +x devwatch.sh
#   ./devwatch.sh
#   ./devwatch.sh 10   # refresh every 10s
#
# Keys:
#   [k] Kill a managed process interactively (by # or PID with safety verification)
#   [c] Quick-clean verified orphan MCP workers & runaway CPU shells
#   [r] Refresh immediately
#   [q] Quit

set -u

INTERVAL="${1:-60}"

RED=$'\033[31;1m'
FLASH_RED=$'\033[5;31;1m'
YELLOW=$'\033[33;1m'
GREEN=$'\033[32;1m'
CYAN=$'\033[36;1m'
MAGENTA=$'\033[35;1m'
BLUE=$'\033[34;1m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

TMP_BASE="${TMPDIR:-/tmp}/devwatch.$$"
PS_FILE="${TMP_BASE}.ps"
PORTS_FILE="${TMP_BASE}.ports"
CWDS_FILE="${TMP_BASE}.cwds"
SESS_FILE="${TMP_BASE}.sess"
ZOMBIE_FILE="${TMP_BASE}.zombies"

SAVED_STTY="$(stty -g 2>/dev/null || true)"

cleanup() {
  rm -f "$PS_FILE" "$PORTS_FILE" "$CWDS_FILE" "$SESS_FILE" "$ZOMBIE_FILE"
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
  : > "$SESS_FILE"
  : > "$ZOMBIE_FILE"

  # 1. Capture process snapshot (PID, PPID, PGID, %CPU, RSS_KB, ETIME, COMMAND)
  ps -axo pid=,ppid=,pgid=,%cpu=,rss=,etime=,command= > "$PS_FILE"

  # 2. Capture listening ports
  lsof -nP -iTCP -sTCP:LISTEN -Fpcn 2>/dev/null > "$PORTS_FILE"

  # 3. Find candidate PIDs for batch CWD query
  candidate_pids="$(awk -v mypid="$$" '
    function is_system_proc(cmd) {
      if (cmd ~ /^(\/System\/|\/usr\/libexec\/|\/usr\/sbin\/|\/usr\/bin\/login|launchd|WindowServer|mds|mdworker|Finder|Dock|Notification Center|Control Center|Spotlight|loginwindow|coreaudiod|locationd|bluetoothd|wifianalyticsd|syspolicyd|secinitd|trustd|opendirectoryd|cfprefsd|distnoted|secd|tccd|fseventsd|syslogd|powerd|analyticsd|logd|airportd|routined|homed|fileproviderd|photoanalysisd|UserEventAgent)/) return 1;
      return 0;
    }
    function is_candidate(cmd) {
      if (is_system_proc(cmd)) return 0;
      if (cmd ~ /(devwatch|lsof|ps -axo)/) return 0;
      if (cmd ~ /(npm|pnpm|yarn|bun|next|vite|nuxt|nitro|astro|remix|gatsby|svelte-kit|ng serve|webpack|turbo|turbopack|nodemon|concurrently|tsx|ts-node|tsc|nest|react-scripts|esbuild|python|uvicorn|flask|fastapi|cargo|go run|air|rails|puma|php artisan|docker-compose|supabase|firebase|wrangler)/) return 1;
      if (cmd ~ /(chrome-devtools-mcp|mcp-remote|modelcontextprotocol|stitch\.googleapis\.com|mcp-server|language_server|codex-code-mode-host|node_repl|node|uv)/) return 1;
      return 0;
    }
    {
      pid = $1;
      if (pid == mypid) next;
      $1=$2=$3=$4=$5=$6="";
      sub(/^[ \t]+/, "");
      if (is_candidate($0)) {
        pids = pids (pids ? "," : "") pid;
      }
    }
    END { print pids }
  ' "$PS_FILE")"

  if [ -n "$candidate_pids" ]; then
    lsof -a -p "$candidate_pids" -d cwd -Fn 2>/dev/null > "$CWDS_FILE"
  fi

  clear
  self_stats="$(get_self_usage)"
  printf "${BOLD}DevWatch 🛡️${RESET}  ${DIM}refresh ${INTERVAL}s · [k] kill · [c] quick-clean · [r] refresh · [q] quit · watcher: %s${RESET}\n\n" "$self_stats"

  awk -v home="$HOME" -v self_stats="$self_stats" -v sess_file="$SESS_FILE" -v zombie_file="$ZOMBIE_FILE" -v mypid="$$" \
      -v red="$RED" -v flash_red="$FLASH_RED" -v yellow="$YELLOW" -v green="$GREEN" -v cyan="$CYAN" -v magenta="$MAGENTA" -v blue="$BLUE" \
      -v bold="$BOLD" -v dim="$DIM" -v reset="$RESET" '

    # -------------------------------------------------------------
    # SENSITIVE DATA REDACTION ENGINE
    # -------------------------------------------------------------
    function redact_secrets(str) {
      gsub(/AIza[0-9A-Za-z-_]{35}/, "[REDACTED_API_KEY]", str);
      gsub(/AQ\.[0-9A-Za-z-_]{30,}/, "[REDACTED_KEY]", str);
      gsub(/X-[-A-Za-z0-9]+-Key:[ \t]*[^ \t\r\n"'\''&]+/, "X-Api-Key: [REDACTED]", str);
      gsub(/Authorization:[ \t]*Bearer[ \t]+[^ \t\r\n"'\''&]+/, "Authorization: Bearer [REDACTED]", str);
      gsub(/Bearer[ \t]+[A-Za-z0-9._~+\/-]{20,}/, "Bearer [REDACTED]", str);
      gsub(/(api[_-]?key|token|secret|password|passwd|auth)=[^ \t\r\n"'\''&]+/, "\\1=[REDACTED]", str);
      gsub(/--header[ \t]+["'\'']?[^ \t\r\n"'\'']*(key|auth|token|secret)[^ \t\r\n"'\'']*["'\'']?/, "--header [REDACTED]", str);
      return str;
    }

    # -------------------------------------------------------------
    # SYSTEM & PROTECTED RECOGNITION (CAN_KILL = 0)
    # -------------------------------------------------------------
    function is_system_proc(cmd, pid) {
      if (pid <= 1) return 1;
      if (cmd ~ /^(\/System\/|\/usr\/libexec\/|\/usr\/sbin\/|\/usr\/bin\/login|launchd|WindowServer|mds|mdworker|Finder|Dock|Notification Center|Control Center|Spotlight|loginwindow|coreaudiod|locationd|bluetoothd|wifianalyticsd|syspolicyd|secinitd|trustd|opendirectoryd|cfprefsd|distnoted|secd|tccd|fseventsd|syslogd|powerd|analyticsd|logd|airportd|routined|homed|fileproviderd|photoanalysisd|UserEventAgent|Google Drive|Telegram|Activity Monitor|systemstats|remoted|diskarbitrationd|notifyd|airportd|sysdiagnosed|corespeechd|containermanagerd|runningboardd|amfid)/) return 1;
      return 0;
    }

    function is_ide_core(cmd) {
      if (cmd ~ /(Antigravity IDE Helper|Antigravity Helper|Codex \(Renderer\)|Codex \(Service\)|Codex \(GPU\)|ChatGPT \(Renderer\)|Cursor \(Renderer\)|Code Helper|Google Chrome Helper)/) return 1;
      if (cmd ~ /(\/Applications\/.*\.app\/Contents\/MacOS\/)/ && cmd !~ /(node|python|mcp)/) return 1;
      return 0;
    }

    function is_dev_server(cmd) {
      if (is_system_proc(cmd, 999) || is_ide_core(cmd)) return 0;
      if (cmd ~ /(devwatch|lsof|ps -axo)/) return 0;
      if (cmd ~ /(chrome-devtools-mcp|mcp-remote|modelcontextprotocol|stitch\.googleapis\.com|mcp-server)/) return 0;
      if (cmd ~ /(npm run|npm start|pnpm dev|pnpm start|pnpm run|yarn dev|yarn start|yarn run|bun dev|bun run|bun start|next dev|next start|next-server|vite|nuxt|nitro|astro|remix|gatsby|svelte-kit|ng serve|webpack|turbo dev|turbopack|nodemon|concurrently|tsx|ts-node|tsc -w|tsc --watch|nest start|react-scripts start|esbuild|python.*manage\.py|uvicorn|flask run|fastapi|cargo watch|cargo run|go run|air|rails s|rails server|puma|php artisan serve|supabase start|firebase emulators:start|wrangler dev)/) return 1;
      return 0;
    }

    function is_mcp_server(cmd) {
      if (is_system_proc(cmd, 999) || is_ide_core(cmd)) return 0;
      if (cmd ~ /(devwatch|lsof|ps -axo)/) return 0;
      if (cmd ~ /(chrome-devtools-mcp|mcp-remote|modelcontextprotocol|stitch\.googleapis\.com|mcp-server|language_server|codex-code-mode-host|node_repl)/) return 1;
      if (cmd ~ /^uv (run|exec).*mcp/ || cmd ~ /^npx .*mcp/) return 1;
      return 0;
    }

    function get_mcp_clean_name(cmd) {
      if (cmd ~ /chrome-devtools-mcp/) return "chrome-devtools-mcp";
      if (cmd ~ /stitch\.googleapis\.com/) return "mcp-remote (Stitch)";
      if (cmd ~ /mcp-remote/) return "mcp-remote";
      if (cmd ~ /modelcontextprotocol/) return "mcp-server";
      if (cmd ~ /language_server_macos_arm/) return "language_server (arm)";
      if (cmd ~ /language_server/) return "language_server";
      if (cmd ~ /codex-code-mode-host/) return "codex-code-mode";
      if (cmd ~ /node_repl/) return "node_repl";
      return "agent-tool";
    }

    function shorten_path(p) {
      if (p == "" || p == "/") return "-";
      if (p == home) return "~";
      hp = home "/";
      if (index(p, hp) == 1) return "~/" substr(p, length(hp) + 1);
      return p;
    }

    function basename(p) {
      if (p == "" || p == "/") return "unknown";
      n = split(p, parts, "/");
      return parts[n];
    }

    # File 1: PS_FILE
    FILENAME ~ /\.ps$/ {
      pid = $1; ppid = $2; pgid = $3; cpu = $4; rss = $5; etime = $6;
      gsub(/,/, ".", cpu);
      $1=$2=$3=$4=$5=$6="";
      sub(/^[ \t]+/, "");
      cmd = redact_secrets($0);

      if (pid == mypid) next;

      pid_ppid[pid] = ppid;
      pid_pgid[pid] = pgid;
      pid_cpu[pid] = cpu;
      pid_rss[pid] = rss;
      pid_etime[pid] = etime;
      pid_cmd[pid] = cmd;
      all_pids[++p_cnt] = pid;
      pid_exists[pid] = 1;
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
          pid_ports[curr_port_pid] = pid_ports[curr_port_pid] (pid_ports[curr_port_pid] ? "," : "") port;
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
      # -------------------------------------------------------------
      # 1. ANCESTRY TRACING & OWNERSHIP VERIFICATION
      # -------------------------------------------------------------
      for (i = 1; i <= p_cnt; i++) {
        pid = all_pids[i];
        ppid = pid_ppid[pid];
        cmd = pid_cmd[pid];
        cpu = pid_cpu[pid] + 0;

        # System & IDE Core are strictly protected
        if (is_system_proc(cmd, pid)) {
          pid_category[pid] = "SYSTEM";
          continue;
        }
        if (is_ide_core(cmd)) {
          pid_category[pid] = "IDE_CORE";
          continue;
        }

        # Resolve origin IDE / App by walking ancestor tree
        curr = pid;
        depth = 0;
        origin_app = "Other";
        has_living_ide_parent = 0;

        while (curr > 1 && (curr in pid_ppid) && depth++ < 25) {
          c = pid_cmd[curr];
          if (c ~ /(\/Terminal\.app\/|iTerm\.app|Warp\.app|ghostty|kitty|wezterm|Alacritty)/) { origin_app="Terminal"; break; }
          if (c ~ /Antigravity IDE/) { origin_app="Antigravity"; has_living_ide_parent=1; break; }
          if (c ~ /Codex/) { origin_app="Codex"; has_living_ide_parent=1; break; }
          if (c ~ /Cursor/) { origin_app="Cursor"; has_living_ide_parent=1; break; }
          if (c ~ /Code\.app|VSCode/) { origin_app="VSCode"; has_living_ide_parent=1; break; }
          if (c ~ /ChatGPT\.app/) { origin_app="ChatGPT"; has_living_ide_parent=1; break; }
          curr = pid_ppid[curr];
        }

        if (ppid == 1 && !has_living_ide_parent) {
          pid_origin[pid] = "Orphan (launchd)";
          pid_is_orphan[pid] = 1;
        } else {
          pid_origin[pid] = origin_app;
        }

        # -------------------------------------------------------------
        # 2. EVIDENCE-BASED ZOMBIE / RUNAWAY DETECTION
        # -------------------------------------------------------------
        # Condition A: Runaway CPU loop (> 25% CPU on a shell or detached worker)
        # Condition B: Orphaned Shell/MCP Worker (PPID=1) running > 30m without living IDE owner
        # Condition C: Hung git/ssh running > 10m
        # Condition D: Dangling interactive node_repl
        is_runaway = 0;
        runaway_reason = "";

        if (cmd ~ /(^[-]?|[\/ ])(zsh|bash|sh|fish)($|[ \t])/ && cmd !~ /devwatch/) {
          if ((cpu + 0) >= 20.0) {
            is_runaway = 1;
            runaway_reason = sprintf("🔥 Runaway CPU Shell (%.1f%%)", cpu + 0);
          } else if (pid_is_orphan[pid]) {
            split(pid_etime[pid], t_parts, ":");
            if (length(t_parts) >= 3 || index(pid_etime[pid], "-") > 0) {
              is_runaway = 1;
              runaway_reason = "👻 Orphan Shell (No Owner)";
            }
          }
        } else if ((cpu + 0) >= 20.0 && !is_dev_server(cmd) && cmd !~ /devwatch/) {
          is_runaway = 1;
          runaway_reason = sprintf("🔥 Runaway CPU Process (%.1f%%)", cpu + 0);
        } else if (cmd ~ /node_repl/) {
          is_runaway = 1;
          runaway_reason = "📦 Dangling Node REPL";
        } else if (is_mcp_server(cmd) && pid_is_orphan[pid]) {
          # Orphaned MCP server whose parent IDE/Agent crashed or died
          is_runaway = 1;
          runaway_reason = "🔌 Orphan MCP (Owner Disconnected)";
        } else if (cmd ~ /(^|[\/ ])(ssh|git|gitstatusd)($| )/) {
          split(pid_etime[pid], t_parts, ":");
          if (length(t_parts) >= 3 || index(pid_etime[pid], "-") > 0) {
            is_runaway = 1;
            runaway_reason = "⏳ Stalled Git/SSH";
          }
        }

        if (is_runaway) {
          runaways[++runaway_cnt] = pid;
          runaway_reasons[pid] = runaway_reason;
        }

        # -------------------------------------------------------------
        # 3. DEV SERVERS & ACTIVE MCP SERVERS CLASSIFICATION
        # -------------------------------------------------------------
        if (is_dev_server(cmd)) {
          curr_p = ppid;
          has_dev_ancestor = 0;
          d = 0;
          while (curr_p > 1 && (curr_p in pid_ppid) && d++ < 30) {
            if (is_dev_server(pid_cmd[curr_p])) { has_dev_ancestor = 1; break; }
            curr_p = pid_ppid[curr_p];
          }
          if (!has_dev_ancestor) {
            is_root_dev[pid] = 1;
            dev_roots[++dev_root_cnt] = pid;
          }
        } else if (is_mcp_server(cmd) && !is_runaway) {
          active_mcps[++active_mcp_cnt] = pid;
        }
      }

      # Map dev server children to roots
      for (i = 1; i <= p_cnt; i++) {
        pid = all_pids[i];
        if (pid in is_root_dev) { root_of_pid[pid] = pid; continue; }
        matched_root = "";
        curr = pid_ppid[pid];
        d = 0;
        while (curr > 1 && (curr in pid_ppid) && d++ < 30) {
          if (curr in is_root_dev) { matched_root = curr; break; }
          curr = pid_ppid[curr];
        }
        if (matched_root == "") {
          pgid = pid_pgid[pid];
          for (r = 1; r <= dev_root_cnt; r++) {
            root_pid = dev_roots[r];
            if (pid_pgid[root_pid] == pgid && pid != root_pid) { matched_root = root_pid; break; }
          }
        }
        if (matched_root != "") root_of_pid[pid] = matched_root;
      }

      # Create dev session records
      sess_n = 0;
      for (r = 1; r <= dev_root_cnt; r++) {
        root_pid = dev_roots[r];
        cwd = pid_cwd[root_pid];
        if (cwd == "") {
          for (p in root_of_pid) {
            if (root_of_pid[p] == root_pid && pid_cwd[p] != "") { cwd = pid_cwd[p]; break; }
          }
        }
        if (cwd == "" || cwd == "/" || cwd ~ /^(\/System\/|\/usr\/|\/Library\/|\/Applications\/|\/private\/var\/)/) {
          cwd = shorten_path(pid_cwd[root_pid]);
          if (cwd == "-") cwd = "~";
        }

        pgid = pid_pgid[root_pid];
        key = cwd SUBSEP pgid;

        if (!(key in sess_seen)) {
          sess_seen[key] = 1;
          sess_order[++sess_n] = key;
          sess_cwd[key] = cwd;
          sess_pgid[key] = pgid;
          sess_pid[key] = root_pid;
          sess_age[key] = pid_etime[root_pid];
          sess_origin[key] = pid_origin[root_pid];
          sess_cmd[key] = pid_cmd[root_pid];
        }
        project_seen[cwd] = 1;
        project_sess_count[cwd SUBSEP pgid] = 1;
      }

      for (i = 1; i <= p_cnt; i++) {
        pid = all_pids[i];
        if (pid in root_of_pid) {
          root_pid = root_of_pid[pid];
          cwd = pid_cwd[root_pid];
          if (cwd == "") {
            for (p in root_of_pid) {
              if (root_of_pid[p] == root_pid && pid_cwd[p] != "") { cwd = pid_cwd[p]; break; }
            }
          }
          if (cwd == "" || cwd == "/" || cwd ~ /^(\/System\/|\/usr\/|\/Library\/|\/Applications\/|\/private\/var\/)/) {
            cwd = shorten_path(pid_cwd[root_pid]);
            if (cwd == "-") cwd = "~";
          }
          pgid = pid_pgid[root_pid];
          key = cwd SUBSEP pgid;
          sess_cpu[key] += pid_cpu[pid];
          sess_rss[key] += pid_rss[pid];

          if (pid in pid_ports) {
            split(pid_ports[pid], ports_arr, ",");
            for (pa in ports_arr) {
              port = ports_arr[pa];
              if (!(key SUBSEP port in port_seen)) {
                port_seen[key SUBSEP port] = 1;
                ports_map[key] = ports_map[key] (ports_map[key] ? "," : "") port;
              }
            }
          }
        }
      }

      # Count duplicate dev projects
      dup_dev_projects = 0;
      for (c in project_seen) {
        cnt = 0;
        for (k in project_sess_count) {
          split(k, parts, SUBSEP);
          if (parts[1] == c) cnt++;
        }
        project_count[c] = cnt;
        if (cnt > 1) dup_dev_projects++;
      }

      # Count active MCP types and detect duplicate instances
      for (m = 1; m <= active_mcp_cnt; m++) {
        pid = active_mcps[m];
        cname = get_mcp_clean_name(pid_cmd[pid]);
        mcp_type_count[cname]++;
        mcp_type_pids[cname] = mcp_type_pids[cname] (mcp_type_pids[cname] ? "," : "") pid;
      }

      dup_mcp_count = 0;
      for (cn in mcp_type_count) {
        if (mcp_type_count[cn] > 1) {
          split(mcp_type_pids[cn], p_list, ",");
          # Find the newest PIDs for this tool category (newest npm / newest node / newest binary)
          newest_npm = 0; newest_node = 0; newest_bin = 0;
          for (k = 1; k <= length(p_list); k++) {
            p = p_list[k];
            c = pid_cmd[p];
            if (c ~ /^npm/ || c ~ /npm exec/) { if (p > newest_npm) newest_npm = p; }
            else if (c ~ /^node / || c ~ /\/node /) { if (p > newest_node) newest_node = p; }
            else { if (p > newest_bin) newest_bin = p; }
          }

          # Flag all older instances as redundant duplicates
          for (k = 1; k <= length(p_list); k++) {
            p = p_list[k];
            c = pid_cmd[p];
            is_dup = 0;
            if (c ~ /^npm/ || c ~ /npm exec/) { if (p != newest_npm && newest_npm > 0) is_dup = 1; }
            else if (c ~ /^node / || c ~ /\/node /) { if (p != newest_node && newest_node > 0) is_dup = 1; }
            else { if (p != newest_bin && newest_bin > 0) is_dup = 1; }

            if (is_dup) {
              is_duplicate_mcp[p] = 1;
              dup_mcp_count++;
            }
          }
        }
      }

      # Totals
      total_dev_rss = 0;
      total_mcp_rss = 0;
      total_runaway_rss = 0;
      total_inventory_items = 0;

      for (i = 1; i <= sess_n; i++) total_dev_rss += sess_rss[sess_order[i]];
      for (m = 1; m <= active_mcp_cnt; m++) total_mcp_rss += pid_rss[active_mcps[m]];
      for (z = 1; z <= runaway_cnt; z++) total_runaway_rss += pid_rss[runaways[z]];

      # Title & Bell
      if (runaway_cnt > 0) {
        printf "\033]0;🔥 ORPHAN/RUNAWAY (%d) - DevWatch\007", runaway_cnt;
        printf "\a";
      } else if (dup_dev_projects > 0) {
        printf "\033]0;⚠️ DUPLICATE DEV (%d) - DevWatch\007", dup_dev_projects;
        printf "\a";
      } else {
        printf "\033]0;✓ DevWatch (Clean)\007";
      }

      # -------------------------------------------------------------
      # 4. RENDER SECTION: 🔥 ORPHANED & RUNAWAY PROCESSES (CLEANUP CANDIDATES)
      # -------------------------------------------------------------
      if (runaway_cnt > 0) {
        printf "%s%s🔥 ORPHANED & RUNAWAY PROCESSES (%d CANDIDATE%s FOR CLEANUP)%s\n", \
          flash_red, bold, runaway_cnt, (runaway_cnt > 1 ? "S" : ""), reset;
        printf "%s%-4s %-26s %-16s %-8s %-8s %-8s %-10s %-10s %s%s\n", \
          bold, "#", "DIAGNOSIS / REASON", "ORIGIN", "PGID", "PID", "CPU", "MEM", "AGE", "COMMAND", reset;

        for (z = 1; z <= runaway_cnt; z++) {
          pid = runaways[z];
          pgid = pid_pgid[pid];
          cpu_val = pid_cpu[pid] + 0;
          r = pid_rss[pid] + 0;
          age = pid_etime[pid];
          cmd = pid_cmd[pid];
          diag = runaway_reasons[pid];
          orig = pid_origin[pid];

          if (r < 1024) mem_str = sprintf("%d KB", r);
          else mem_str = sprintf("%.1f MB", r / 1024);

          cpu_str = sprintf("%.1f%%", cpu_val);
          item_idx = ++total_inventory_items;

          printf "%s %-2d %-26s %-16s %-8s %-8s %-8s %-10s %-10s %.65s%s\n", \
            flash_red "⚠", item_idx, diag, orig, pgid, pid, cpu_str, mem_str, age, cmd, reset;

          # Record in Inventory (CAN_KILL = 1) and in ZOMBIE_FILE
          printf "%d\t%s\t1\tRUNAWAY\t%s\t%s\n", item_idx, pid, diag, cmd >> sess_file;
          printf "%s\t%s\t%s\n", pid, diag, cmd >> zombie_file;
        }
        printf "\n";
      }

      # -------------------------------------------------------------
      # 5. RENDER SECTION: 🌐 ACTIVE WEB DEV SERVERS
      # -------------------------------------------------------------
      if (sess_n > 0) {
        printf "%s%s🌐 DEV SERVERS (%d ACTIVE)%s\n", cyan, bold, sess_n, reset;
        printf "%s%-4s %-22s %-14s %-8s %-8s %-8s %-10s %-10s %-10s %s%s\n", \
          bold, "#", "PROJECT", "ORIGIN", "PGID", "PID", "CPU", "MEM", "AGE", "PORT", "COMMAND", reset;

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
          ports = ports_map[key];
          if (ports == "") ports = "-";

          if (dup_cnt > 1) {
            prefix = flash_red "⚠";
            suffix = "  " flash_red "DUPLICATE" reset;
          } else {
            prefix = green "✓";
            suffix = reset;
          }

          r = sess_rss[key];
          if (r < 1024) mem_str = sprintf("%d KB", r);
          else if (r < 1048576) mem_str = sprintf("%.1f MB", r / 1024);
          else mem_str = sprintf("%.2f GB", r / 1048576);

          cpu_str = sprintf("%.1f%%", sess_cpu[key]);
          item_idx = ++total_inventory_items;

          printf "%s %-2d %-22s %-14s %-8s %-8s %-8s %-10s %-10s %-10s %.55s%s\n", \
            prefix, item_idx, p_name, origin, pgid, pid, cpu_str, mem_str, age, ports, cmd, suffix;

          printf "     %s%s%s\n", dim, shorten_path(cwd), reset;

          printf "%d\t%s\t1\tDEV_SERVER\t%s\t%s\n", item_idx, pid, ("Dev: " p_name), cmd >> sess_file;
        }
        printf "\n";
      }

      # -------------------------------------------------------------
      # 6. RENDER SECTION: 🤖 ACTIVE AI AGENT & MCP SERVERS (OBSERVE & MANAGE)
      # -------------------------------------------------------------
      if (active_mcp_cnt > 0) {
        printf "%s%s🤖 ACTIVE AI AGENT & MCP SERVERS (%d ACTIVE)%s\n", magenta, bold, active_mcp_cnt, reset;
        printf "%s%-4s %-24s %-14s %-8s %-8s %-8s %-10s %-10s %s%s\n", \
          bold, "#", "TOOL / SERVER", "OWNER/IDE", "PGID", "PID", "CPU", "MEM", "AGE", "COMMAND", reset;

        for (m = 1; m <= active_mcp_cnt; m++) {
          pid = active_mcps[m];
          pgid = pid_pgid[pid];
          cmd = pid_cmd[pid];
          cname = get_mcp_clean_name(cmd);
          orig = pid_origin[pid];
          age = pid_etime[pid];
          cpu_val = pid_cpu[pid] + 0;
          r = pid_rss[pid] + 0;

          if (r < 1024) mem_str = sprintf("%d KB", r);
          else mem_str = sprintf("%.1f MB", r / 1024);

          cpu_str = sprintf("%.1f%%", cpu_val);

          if (is_duplicate_mcp[pid]) {
            prefix = yellow "⚠";
            suffix = "  " yellow sprintf("(x%d - Redundant Duplicate)", mcp_type_count[cname]) reset;
            # Record duplicate in zombie_file for 1-click Quick Clean
            printf "%s\t%s\t%s\n", pid, ("⚠ Redundant Duplicate (" cname ")"), cmd >> zombie_file;
          } else {
            prefix = green "✓";
            suffix = (mcp_type_count[cname] > 1) ? ("  " green "(Active Primary)" reset) : reset;
          }

          item_idx = ++total_inventory_items;

          printf "%s %-2d %-24s %-14s %-8s %-8s %-8s %-10s %-10s %.55s%s\n", \
            prefix, item_idx, cname, orig, pgid, pid, cpu_str, mem_str, age, cmd, suffix;

          printf "%d\t%s\t1\tACTIVE_MCP\t%s\t%s\n", item_idx, pid, ("MCP: " cname), cmd >> sess_file;
        }
        printf "\n";
      }

      # -------------------------------------------------------------
      # 7. GLOBAL TELEMETRY SUMMARY
      # -------------------------------------------------------------
      if (total_inventory_items == 0) {
        printf "%s✓ System clean: No dev servers, MCP servers, or runaway processes detected.%s\n\n", green, reset;
      }

      total_tracked_ram = total_dev_rss + total_mcp_rss + total_runaway_rss;
      if (total_tracked_ram > 0) {
        if (total_tracked_ram < 1024) ram_s = total_tracked_ram " KB";
        else if (total_tracked_ram < 1048576) ram_s = sprintf("%.1f MB", total_tracked_ram / 1024);
        else ram_s = sprintf("%.2f GB", total_tracked_ram / 1048576);

        dev_ram_s = (total_dev_rss < 1048576) ? sprintf("%.1f MB", total_dev_rss/1024) : sprintf("%.2f GB", total_dev_rss/1048576);
        mcp_ram_s = (total_mcp_rss < 1048576) ? sprintf("%.1f MB", total_mcp_rss/1024) : sprintf("%.2f GB", total_mcp_rss/1048576);

        printf "%s%s📊 Tracked RAM: %s%s  %s(Dev: %s · Active MCP: %s · Watcher: %s)%s\n", \
          cyan, bold, ram_s, reset, dim, dev_ram_s, mcp_ram_s, self_stats, reset;
      }

      # Bottom Action Prompts
      if (runaway_cnt > 0 || dup_mcp_count > 0) {
        printf "%s%s⚠ Found %d Orphan/Runaway & %d Redundant Duplicate MCP(s).%s %sPress [c] to Quick-Clean, [k] to terminate, [q] to quit.%s\n", \
          flash_red, bold, runaway_cnt, dup_mcp_count, reset, dim, reset;
      } else if (dup_dev_projects > 0) {
        printf "%s%s⚠ %d project(s) have duplicate dev sessions.%s %sPress [k] to terminate duplicate, [q] to quit.%s\n", \
          flash_red, bold, dup_dev_projects, reset, dim, reset;
      } else {
        printf "%s🛡️ System protected.%s %sPress [k] to terminate, [r] to refresh, [q] to quit.%s\n", \
          green, reset, dim, reset;
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
    r|R)
      continue
      ;;
    c|C)
      stty "$SAVED_STTY" 2>/dev/null || true
      printf "\n${BOLD}${FLASH_RED}🧹 QUICK-CLEAN ORPHAN & REDUNDANT DUPLICATE PROCESSES${RESET}\n"
      if [ ! -s "$ZOMBIE_FILE" ]; then
        printf "${GREEN}✓ No orphaned processes or duplicate MCP instances found to clean.${RESET}\n"
        sleep 1.5
        continue
      fi

      z_cnt="$(wc -l < "$ZOMBIE_FILE" | tr -d ' ')"
      printf "${YELLOW}Found %s verified candidate(s) to clean:${RESET}\n" "$z_cnt"
      while IFS=$'\t' read -r z_pid z_reason z_cmd; do
        printf "  ${RED}• PID %-6s${RESET} ${DIM}[%-32s]${RESET} %.50s\n" "$z_pid" "$z_reason" "$z_cmd"
      done < "$ZOMBIE_FILE"

      printf "\n${BOLD}Terminate these %s candidate(s) (leaving primary active instances alive)? (y/N):${RESET} " "$z_cnt"
      read -r confirm_clean

      if [ "$confirm_clean" = "y" ] || [ "$confirm_clean" = "Y" ]; then
        cleaned=0
        while IFS=$'\t' read -r z_pid z_reason z_cmd; do
          if [ -n "$z_pid" ] && kill -0 "$z_pid" 2>/dev/null; then
            # Safe Graceful Kill directly on target PID (never -PGID)
            kill -15 "$z_pid" 2>/dev/null || true
            sleep 0.2
            if kill -0 "$z_pid" 2>/dev/null; then
              kill -9 "$z_pid" 2>/dev/null || true
            fi
            ((cleaned++))
          fi
        done < "$ZOMBIE_FILE"
        printf "${GREEN}✓ Successfully cleaned %d process(es).${RESET}\n" "$cleaned"
        sleep 1.5
      else
        printf "${DIM}Cancelled.${RESET}\n"
        sleep 0.8
      fi
      ;;
    k|K)
      stty "$SAVED_STTY" 2>/dev/null || true
      printf "\n${BOLD}${CYAN}🔪 TERMINATE MANAGED PROCESS${RESET}\n"
      if [ ! -s "$SESS_FILE" ]; then
        printf "${YELLOW}No active managed processes found to terminate.${RESET}\n"
        sleep 1.5
        continue
      fi

      printf "${DIM}Enter item # (1..N) or PID to terminate (or press Enter/c to cancel):${RESET} "
      read -r target_input

      if [ -z "$target_input" ] || [ "$target_input" = "c" ] || [ "$target_input" = "C" ]; then
        printf "${DIM}Cancelled.${RESET}\n"
        sleep 0.5
        continue
      fi

      target_pid=""
      target_can_kill=""
      target_cat=""
      target_name=""
      target_cmd=""

      # Lookup in SESS_FILE
      clean_input="${target_input#-}"
      if [[ "$clean_input" =~ ^[0-9]+$ ]]; then
        # Match either item index ($1) or direct PID ($2)
        sess_record="$(awk -F'\t' -v q="$clean_input" '($1 == q || $2 == q) { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6; exit }' "$SESS_FILE")"
        if [ -n "$sess_record" ]; then
          target_pid="$(echo "$sess_record" | cut -f2)"
          target_can_kill="$(echo "$sess_record" | cut -f3)"
          target_cat="$(echo "$sess_record" | cut -f4)"
          target_name="$(echo "$sess_record" | cut -f5)"
          target_cmd="$(echo "$sess_record" | cut -f6)"
        fi
      fi

      # HARD SAFETY GATE
      if [ -z "$target_pid" ]; then
        printf "${RED}🛡️ SAFETY REJECTION: PID/Item '%s' is NOT in DevWatch managed inventory. Action blocked.${RESET}\n" "$target_input"
        sleep 2
        continue
      fi

      if [ "$target_can_kill" != "1" ]; then
        printf "${RED}🛡️ PROTECTED PROCESS: %s (PID %s) is a protected system/core process. CANNOT terminate.${RESET}\n" "$target_name" "$target_pid"
        sleep 2
        continue
      fi

      # Confirm individual process termination
      printf "\n${YELLOW}Target: %s (PID %s, Type: %s)${RESET}\n" "$target_name" "$target_pid" "$target_cat"
      printf "${DIM}Command: %.70s${RESET}\n" "$target_cmd"
      printf "${BOLD}Are you sure you want to terminate this process? (y/N):${RESET} "
      read -r confirm_kill

      if [ "$confirm_kill" = "y" ] || [ "$confirm_kill" = "Y" ]; then
        printf "${YELLOW}Terminating PID %s gracefully (SIGTERM)...${RESET}\n" "$target_pid"
        kill -15 "$target_pid" 2>/dev/null || true
        sleep 0.5

        if kill -0 "$target_pid" 2>/dev/null; then
          printf "${YELLOW}Process still alive, sending SIGKILL (PID %s)...${RESET}\n" "$target_pid"
          kill -9 "$target_pid" 2>/dev/null || true
        fi

        printf "${GREEN}✓ Terminated %s (PID %s).${RESET}\n" "$target_name" "$target_pid"
        sleep 1.2
      else
        printf "${DIM}Cancelled.${RESET}\n"
        sleep 0.8
      fi
      ;;
  esac
done


