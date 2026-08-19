# DevWatch 🛡️

> **Bộ công cụ giám sát dev server & AI Agent siêu nhẹ cho macOS**

**DevWatch** là công cụ CLI và ứng dụng macOS siêu nhanh, giúp tự động phát hiện, theo dõi các tiến trình dev (`npm run dev`, `vite`, `next dev`, `bun`, `nodemon`,...) do bạn hoặc các **AI Coding Agent** (như **Antigravity IDE**, **Codex**, **ChatGPT**, **Terminal**) khởi chạy ngầm.

---

## 💥 Vấn đề gặp phải

Khi làm việc với các AI Coding Agent, agent thường tự bật thêm dev server ở các port khác nhau cho cùng một dự án. Theo thời gian:

- ❌ **Tích tụ hàng loạt tiến trình trùng lặp** ngốn RAM và làm nóng máy Mac.
- ❌ **Xung đột port** (port 3000, 3001, 3002 đều bị chiếm bởi 1 dự án).
- ❌ Dung lượng RAM bị chiếm dụng có thể lên tới nhiều GB.

---

## ✨ Giải pháp từ DevWatch

DevWatch gom nhóm tất cả tiến trình dev theo thư mục dự án (CWD) và ID nhóm tiến trình (PGID):

- 🚨 **Cảnh báo trùng lặp (Duplicate)**: Phát hiện dự án nào đang chạy từ 2 session trở lên.
- 🤖 **Nhận diện nguồn phát (Origin)**: Biết chính xác session được mở từ đâu (**Antigravity IDE**, **Terminal**, **Codex**, **ChatGPT**).
- 📊 **RAM & CPU Real-time**: Hiển thị chính xác dung lượng RAM (MB / GB) và % CPU theo từng session + tổng RAM dev toàn máy.
- 🔌 **Mapping Cổng LISTEN**: Hiển thị các port mà session đang lắng nghe.
- 🔔 **Cảnh báo trực quan**: Tự động đổi Title cửa sổ Terminal (`⚠️ DUPLICATE`) và nhấp nháy đỏ khi phát hiện trùng.
- ⚡ **Siêu nhẹ & Nhanh**: Thời gian quét **~100ms**, chỉ chiếm **~1.5 MB RAM** watcher.

## 📦 Cài đặt 1 dòng lệnh (One-line Install)

Chạy 1 dòng lệnh sau trong Terminal (không cần `git clone` hay pull source):

```bash
curl -fsSL https://raw.githubusercontent.com/datdoan/dev-watch/main/install.sh | bash
```

_(Lệnh trên sẽ tự động cài `devwatch` CLI và tự build `DevWatch.app` vào `/Applications`)_

---

## 🚀 Hướng dẫn sử dụng

### 1. Lệnh Terminal (CLI)

Chạy trực tiếp từ **bất kỳ Terminal nào** (Terminal, iTerm2, Warp, Ghostty, VS Code,...):

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

- **`k`**: Mở chế độ diệt tiến trình (Kill Session) trực tiếp theo số thứ tự `#` (1, 2,...), PID, hoặc PGID.
- **`r`**: Bắt buộc quét & làm mới giao diện ngay lập tức.
- **`q`**: Thoát DevWatch.
- **`Ctrl + C`**: Dừng chương trình.

---

## 🧹 Cách tắt an toàn một Session bị trùng

1. **Thao tác trực tiếp trong DevWatch**: Nhấn phím `k`, nhập số thứ tự session (ví dụ `1`) hoặc nhập `PGID`/`PID` và nhấn `Enter`. DevWatch sẽ tự động diệt triệt để nhóm tiến trình (PGID).
2. **Thao tác thủ công qua Terminal**:

```bash
kill -- -PGID
```

_(Thay `PGID` bằng số PGID hiển thị trên bảng, ví dụ: `kill -- -81204`)_
