# DevWatch 🛡️

> **Bộ công cụ giám sát & dọn dẹp Dev Server, AI Agent MCP & Zombie Process siêu nhẹ, an toàn tuyệt đối cho macOS**

**DevWatch** là công cụ CLI và ứng dụng macOS siêu nhanh (~100ms), giúp tự động phát hiện, cảnh báo và quản lý an toàn:
1. **Web Dev Servers**: `npm run dev`, `vite`, `next dev`, `bun`, `uvicorn`, `fastapi`, `cargo watch`, `go run`,...
2. **AI Agent & MCP Servers**: `chrome-devtools-mcp`, `mcp-remote` (Stitch), `language_server`, `codex-code-mode-host`, `python3.13`, `uv`...
3. **Redundant Duplicate Instances**: Nhận diện và phân tách bản đang dùng (`Active Primary`) và các bản sao thừa thãi (`Redundant Duplicate`) sinh ra sau các lần reload agent.
4. **Orphaned & Runaway Processes**: Subshell mồ côi ăn CPU cao (vòng lặp vô tận), MCP worker mất kết nối IDE cha (`PPID=1`), dangling `node_repl` hoặc `git`/`ssh` bị treo.

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

- ❌ **Tích tụ MCP Server & Node REPL mồ côi**: Mỗi session/subagent bật một MCP server mới nhưng không tự thoát khi cửa sổ đóng.
- ❌ **Subshell đốt 100% CPU**: Các vòng lặp subshell chạy nền bị bỏ rơi (reparent về `launchd`) làm nóng máy và cạn pin.
- ❌ **Nhân bản MCP trùng lặp (Duplicate MCPs)**: Hàng chục instance của cùng 1 tool (`mcp-remote`, `chrome-devtools-mcp`) chạy đè lên nhau ngốn 1.5 - 2+ GB RAM.
- ❌ **Xung đột Web Dev Server**: Cùng 1 dự án mở nhiều dev server ở port 3000, 3001, 3002.

---

## ✨ Tính năng nổi bật của DevWatch

- 🚨 **Phân loại có bằng chứng (Evidence-based Classification)**:
  - 🔥 **ORPHANED & RUNAWAY**: Nhận diện chính xác shell ăn CPU cao ($\ge 20\%$) hoặc worker mất cha (`PPID=1`), dangling `node_repl`.
  - 🌐 **DEV SERVERS**: Gom nhóm theo thư mục dự án (CWD), Port LISTEN và cảnh báo DUPLICATE.
  - 🤖 **ACTIVE AI AGENT & MCP SERVERS**: Phân tách rõ ràng bản `Active Primary` đang kết nối với IDE và các bản `Redundant Duplicate` thừa thãi.
- 🤖 **Nhận diện nguồn phát (Origin Tracking)**: Xác định chính xác tiến trình mở từ **Antigravity**, **Codex**, **Cursor**, **ChatGPT**, **Terminal**, hay **Orphan (launchd)**.
- 📊 **Đo lường RAM & CPU chuẩn xác**: Phân tách rõ ràng Tổng RAM = RAM Dev + RAM Agent/MCP.
- 🧹 **1-Click Quick Clean (`c`)**: Dọn sạch toàn bộ Worker mồ côi, Dangling REPL và các bản sao MCP trùng lặp cũ chỉ với 1 phím bấm sau khi xem danh sách xác nhận.
- ⚡ **Siêu nhẹ & Nhanh**: Quét toàn bộ hệ thống trong **~100ms**, watcher chỉ chiếm **~1.5 MB RAM** và **0.0% CPU**.

---

## 📦 Cài đặt & Sử dụng

### Cách 1: Chạy trực tiếp (Nhanh nhất)
```bash
./devwatch.sh 5
```

### Cách 2: Đóng gói App macOS (`DevWatch.app`) & Lệnh toàn cục
```bash
./build_mac_app.sh
```
_(Tự động cài `DevWatch.app` vào `/Applications` và tạo lệnh `devwatch` toàn cục trong Terminal)_

### Cách 3: Cài đặt từ xa 1 dòng lệnh (One-line Install)
```bash
curl -fsSL https://raw.githubusercontent.com/datdoan/dev-watch/main/install.sh | bash
```

---

## ⌨️ Phím tắt điều khiển trong DevWatch

- **`c`**: **Quick-Clean** - Xem trước danh sách và dọn sạch các tiến trình mồ côi / runaway / redundant duplicate MCP đã được xác minh an toàn.
- **`k`**: **Kill Process** - Mở chế độ diệt tiến trình an toàn theo số thứ tự `#` (1..N) hoặc PID.
- **`r`**: Bắt buộc quét & làm mới giao diện ngay lập tức.
- **`q`**: Thoát DevWatch.
- **`Ctrl + C`**: Dừng chương trình.

---

## 🤖 Tích hợp AI Agent (Rules & Skills)

- **Agent Rules**: Xem file [`AGENTS.md`](./AGENTS.md) để nắm rõ quy tắc bắt buộc về an toàn tiến trình, vòng đời worker và bảo mật secret cho AI Agents.
- **Agent Skill**: Tích hợp sẵn skill tại [`skills/devwatch/SKILL.md`](./skills/devwatch/SKILL.md) và [`.agents/skills/devwatch/SKILL.md`](./.agents/skills/devwatch/SKILL.md) giúp AI Agents tự động kích hoạt chẩn đoán và dọn dẹp môi trường phát triển khi cần thiết.
