# DevWatch 🛡️

> **Bộ công cụ giám sát Dev Server & AI Agent siêu nhẹ, an toàn tuyệt đối cho macOS**

**DevWatch** là công cụ CLI và ứng dụng macOS siêu nhanh (~100ms), giúp tự động phát hiện, cảnh báo và quản lý:
1. **Web Dev Servers**: `npm run dev`, `vite`, `next dev`, `bun`, `uvicorn`, `fastapi`, `cargo watch`, `go run`,...
2. **AI Agent & MCP Servers**: `chrome-devtools-mcp`, `mcp-remote` (Stitch), `language_server`, `codex-code-mode-host`,...
3. **Orphaned & Runaway Processes**: Các subshell mồ côi ăn CPU cao (vòng lặp vô tận), MCP worker mất kết nối IDE cha, REPL `node_repl` hoặc `git`/`ssh` bị treo.

---

## 🛡️ Cam kết An toàn Tuyệt đối (Safety Guarantee)

DevWatch được thiết kế với **Chốt chặn an toàn (Hard Safety Gate)** đa tầng:
- 🚫 **KHÔNG BAO GIỜ chạm vào tiến trình hệ điều hành (macOS kernel, daemons, root, WindowServer, launchd, audio/network/spotlight services)**.
- 🚫 **KHÔNG BAO GIỜ chạm vào tiến trình cốt lõi của IDE / Browser** (Codex Renderer, Antigravity Helper, Chrome Main,...).
- 🔒 **Tự động che giấu thông tin nhạy cảm (Secret Redaction)**: Mọi API Key (`X-Goog-Api-Key`, `AIza...`), Bearer Token, Password, Header trong command đều tự động được redact thành `[REDACTED]`.
- 🎯 **Chỉ diệt chính xác PID mục tiêu**: Tuyệt đối không kill bừa bãi theo nhóm tiến trình (`-PGID`), không làm ảnh hưởng tới Terminal hay IDE cha.
- 🛡️ **Từ chối thao tác ngoài danh mục**: Mọi yêu cầu kill PID không thuộc danh sách quản lý đã xác minh của DevWatch đều bị chặn ngay lập tức.

---

## 💥 Vấn đề gặp phải khi dùng AI Coding Agents

Khi làm việc với các AI Coding Agent (**Antigravity IDE**, **Codex**, **Cursor**, **Claude Code**, **ChatGPT**,...):

- ❌ **Tích tụ MCP Server mồ côi**: Mỗi session/subagent bật một MCP server mới nhưng không tự thoát khi cửa sổ đóng.
- ❌ **Subshell đốt 100% CPU**: Các vòng lặp subshell chạy nền bị bỏ rơi (reparent về `launchd`) làm nóng máy và cạn pin.
- ❌ **Xung đột Web Dev Server**: Cùng 1 dự án mở nhiều dev server ở port 3000, 3001, 3002.
- ❌ **Chiếm dụng RAM khổng lồ**: Hàng GB RAM bị lãng phí cho các tiến trình ngầm không còn sử dụng.

---

## ✨ Tính năng nổi bật của DevWatch

- 🚨 **Phân loại có bằng chứng (Evidence-based Classification)**:
  - 🔥 **ORPHANED & RUNAWAY**: Nhận diện chính xác shell ăn CPU cao (>25%) hoặc worker mất cha (PPID=1).
  - 🌐 **DEV SERVERS**: Gom nhóm theo thư mục dự án (CWD), Port LISTEN và cảnh báo DUPLICATE.
  - 🤖 **ACTIVE MCP SERVERS**: Theo dõi MCP Server của các IDE đang sống mà không làm gián đoạn công việc.
- 🤖 **Nhận diện nguồn phát (Origin)**: Xác định chính xác tiến trình mở từ **Antigravity**, **Codex**, **Cursor**, **ChatGPT**, **Terminal**, hay **Orphan (launchd)**.
- 📊 **Đo lường RAM & CPU chuẩn xác**: Phân tách rõ ràng Tổng RAM = RAM Dev + RAM Agent/MCP.
- 🧹 **1-Click Quick Clean (`c`)**: Dọn sạch toàn bộ Worker mồ côi và Shell runaway chỉ với 1 phím bấm sau khi xác nhận.
- ⚡ **Siêu nhẹ & Nhanh**: Quét toàn bộ hệ thống trong **~100ms**, watcher chỉ chiếm **~1.5 MB RAM**.

---

## 📦 Cài đặt 1 dòng lệnh (One-line Install)

Chạy lệnh sau trong Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/datdoan/dev-watch/main/install.sh | bash
```

_(Tự động cài `devwatch` CLI vào `~/.local/bin` và build `DevWatch.app` vào `/Applications`)_

---

## 🚀 Hướng dẫn sử dụng

### 1. Lệnh Terminal (CLI)

```bash
# Quét mặc định (refresh 60s)
devwatch

# Quét với thời gian tùy chỉnh (ví dụ 10s)
devwatch 10
```

### 2. Ứng dụng macOS (`DevWatch.app`)

- Mở nhanh qua **Spotlight** (`Cmd + Space` ➔ nhập `DevWatch`).
- Hoặc bấm đúp vào **DevWatch** trong thư mục `/Applications`.

---

## ⌨️ Phím tắt điều khiển

- **`c`**: **Quick-Clean** - Xem trước và dọn sạch các tiến trình mồ côi / runaway đã được xác minh an toàn.
- **`k`**: **Kill Process** - Mở chế độ diệt tiến trình có chốt chặn an toàn theo số thứ tự `#` (1..N) hoặc PID.
- **`r`**: Bắt buộc quét & làm mới giao diện ngay lập tức.
- **`q`**: Thoát DevWatch.
- **`Ctrl + C`**: Dừng chương trình.


