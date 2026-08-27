---
name: devwatch
description: >-
  Monitors, inspects, and safely manages web dev servers, AI agent MCP servers,
  dangling node/python REPLs, and runaway zombie processes without touching OS system processes.
  Activate when diagnosing high CPU/RAM, inspecting port collisions, or cleaning up orphaned AI agent processes.
---

# DevWatch Skill: Safe Process & Dev Environment Guardian

DevWatch is an ultra-lightweight, zero-dependency process manager for macOS & Linux designed specifically for developers and AI coding agents. It provides evidence-based process classification, automatic secret redaction, and strict hardware-level safety guardrails.

---

## When to Activate This Skill

- User reports **high CPU usage**, fan noise, battery drain, or slow system performance.
- User complains about **port collisions** (e.g., `Port 3000 is already in use`).
- Multiple AI agents (Antigravity, Codex, Cursor, ChatGPT) have left behind **duplicate MCP servers** or **dangling REPL sessions**.
- User asks to inspect active dev servers, verify memory usage, or clean up zombie processes.

---

## Core Principles & Safety Mandate

> [!CAUTION]
> **ABSOLUTE SYSTEM IMMUNITY**
> DevWatch enforces hard safety gates (`CAN_KILL = 0`) on all macOS/Linux system daemons, kernel tasks, and parent IDE applications. No automated or manual kill command can ever target protected OS processes.

### Evidence-Based Classification

Category | Criteria | Killable (`CAN_KILL`) | Action
:--- | :--- | :---: | :---
`SYSTEM` | Root daemons, macOS core, `kernel_task`, `launchd`, `WindowServer`, `mds`, `coreaudiod`... | **0 (Blocked)** | Strictly Protected & Ignored
`IDE_CORE` | `Antigravity IDE`, `Codex`, `Cursor`, `Code.app`, `ChatGPT.app` | **0 (Blocked)** | Observed only for ancestry tracing
`DEV_SERVER` | Next.js, Vite, FastAPI, Uvicorn, Rails, Docker, Supabase (grouped by CWD + Port) | **1 (Managed)** | Manage via `#` or PID
`ACTIVE_MCP` | MCP servers (`mcp-remote`, `chrome-devtools-mcp`, `python3`, `language_server`) | **1 (Managed)** | Newest instance is preserved as `Active Primary`
`RUNAWAY` / `ORPHAN` | Subshell CPU $\ge 20\%$, disconnected MCP (`PPID=1`), dangling `node_repl`, stalled `git`/`ssh` | **1 (Managed)** | Eligible for 1-Click Quick-Clean (`c`)

---

## Step-by-Step Diagnostic & Cleanup Workflows

### 1. Launching Live Monitor
Run DevWatch directly from the repository root:
```bash
./devwatch.sh [interval_seconds]
# Example: refresh every 5 seconds
./devwatch.sh 5
```

### 2. Performing 1-Click Quick Clean (`c`)
When DevWatch detects runaway subshells, dangling REPLs, or older duplicate MCP instances:
1. Press key **`c`** in the DevWatch terminal.
2. DevWatch presents a preview list of all verified cleanup candidates with clear diagnostic reasons:
   - `[🔥 Runaway CPU Shell (99.8%)]`
   - `[📦 Dangling Node REPL]`
   - `[⚠ Redundant Duplicate (mcp-remote)]`
   - `[🔌 Orphan MCP (Owner Disconnected)]`
3. Enter **`y`** to confirm.
4. DevWatch sends a graceful `SIGTERM` directly to the candidate PIDs, followed by `SIGKILL` only if still lingering after a 0.2s grace period. **Process groups (`-PGID`) are never blindly nuked.**

### 3. Terminating an Individual Process (`k`)
1. Press key **`k`**.
2. Enter the item number (e.g. `1`, `5`) or exact `PID`.
3. DevWatch checks the safety inventory:
   - If PID is `SYSTEM` or `IDE_CORE`: **Action is immediately rejected**.
   - If PID is valid: Safely terminates that specific process.

---

## Secret & Privacy Redaction

DevWatch automatically intercepts process commands and masks sensitive authentication parameters before rendering to screen or writing to logs:
- `X-Goog-Api-Key: AQ...` ➔ `X-Goog-Api-Key: [REDACTED_API_KEY]`
- `AIza...` ➔ `[REDACTED_API_KEY]`
- `Bearer eyJ...` ➔ `Bearer [REDACTED_TOKEN]`
- `--password <secret>` ➔ `--password [REDACTED_PASSWORD]`

---

## Maintenance & Build Commands

Command | Description
:--- | :---
`./devwatch.sh 5` | Run live watcher directly (no build needed)
`./build_mac_app.sh` | Compile `DevWatch.app` into `/Applications` & link global `devwatch` CLI
`./install.sh` | 1-line remote/local installer for macOS
