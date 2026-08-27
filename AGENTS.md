# AI Agent Rules & Process Safety Guidelines

This document outlines mandatory operational rules and safety constraints for all AI coding agents (Google Antigravity, OpenAI Codex, Cursor, Claude Code, ChatGPT, etc.) operating in this workspace and system.

---

## 1. 🛡️ Absolute System Safety (Non-Negotiable)

> [!CAUTION]
> **NEVER KILL OR MODIFY SYSTEM PROCESSES**
> AI Agents are strictly prohibited from terminating, signaling, or altering any macOS/Linux system daemons, kernel services, or OS core components.

- **Protected System Processes**: `kernel_task`, `launchd`, `WindowServer`, `mds`, `mds_stores`, `mdworker`, `coreaudiod`, `locationd`, `bluetoothd`, `syspolicyd`, `secinitd`, `trustd`, `opendirectoryd`, `cfprefsd`, `distnoted`, `secd`, `tccd`, `fseventsd`, `syslogd`, `powerd`, `analyticsd`, `logd`, `airportd`, `routined`, `homed`, `fileproviderd`, `photoanalysisd`, `UserEventAgent`, `Finder`, `Dock`, `SystemUIServer`, `Control Center`, `Notification Center`, `loginwindow`, `WindowManager`, etc.
- **Protected IDE Core Processes**: Do not terminate the parent IDE application or its core renderer/GPU processes (`Antigravity IDE`, `Codex`, `Cursor`, `Code.app`, `ChatGPT.app`).

---

## 2. 🧹 Subprocess & Worker Lifecycle Hygiene

When spawning subshells, background tasks, REPLs, or tool servers:

1. **No Hanging Background REPLs**: Never leave interactive REPL sessions (`node`, `python`, `php -a`, `irb`, `node_repl`) hanging indefinitely in the background without active stdin/stdout. Always exit REPLs or use non-interactive one-shot scripts (`node -e "..."`, `python3 -c "..."`).
2. **Prevent Infinite Loops & Runaway CPU**: All background workers and polling loops MUST include an explicit exit condition and an appropriate delay (`sleep 1`). Runaway shells consuming $\ge 20\%$ continuous CPU will be flagged and terminated by DevWatch.
3. **Clean Up on Termination**: When an agent session completes or errors out, all spawned sub-workers and child processes must be gracefully terminated (`SIGTERM`).
4. **No Orphan MCP Servers**: MCP servers must handle `stdin` EOF gracefully and exit immediately when the parent IDE or agent disconnects.

---

## 3. 🔒 Secret & Credential Hygiene

> [!WARNING]
> **NEVER PASS SECRETS IN COMMAND-LINE ARGUMENTS**
> Command-line arguments in `ps` and `top` are visible to all processes running under the same user.

- **Forbidden**: Passing API keys, Bearer tokens, or passwords directly via CLI flags (e.g. `npm exec mcp-server --header X-Goog-Api-Key: AQ...`).
- **Required**: Pass secrets via **environment variables** (`export API_KEY="..."` or `.env` files) or secure config files.

---

## 4. 🔍 Using DevWatch for Process & Server Management

When diagnosing runaway CPU, high memory usage, duplicate dev servers, or dangling tool workers:

1. **Check Process Inventory**:
   ```bash
   # Run DevWatch in monitoring mode
   ./devwatch.sh 5
   ```
2. **Clean Verified Zombie & Redundant Processes**:
   - Press **`c` (Quick-Clean)** to review and clean all verified orphan shells, dangling REPLs, and older duplicate MCP instances.
   - Press **`k` (Kill)** to terminate an individual managed dev server or tool by `#` or `PID`.
3. **Verify System Cleanliness**:
   - DevWatch automatically displays total tracked RAM and ensures 0% CPU consumption from its own watcher.
