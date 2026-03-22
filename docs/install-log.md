# 安装过程详细记录

> 2026-03-21 在 OPPO A5 Pro (Android 14) 上安装 OpenClaw 的完整过程。

## 环境

- 服务器: Ubuntu, OpenClaw 2026.3.13
- 手机: OPPO A5 Pro, Android 14, Termux
- 网络: 局域网 192.168.100.0/24

## Timeline

| 时间 | 操作 | 结果 |
|------|------|------|
| 21:24 | 手机直接 `npm install -g openclaw` | ❌ 每包 100s+，太慢 |
| 21:31 | 切换到服务器预下载方案 | 进行中 |
| 21:52 | 服务器执行 npm install | ❌ git SSH 依赖失败 |
| 21:53 | 尝试 git config 修复 | ❌ 超时 |
| 22:02 | 多种 git config 方案 | ❌ 不生效 |
| 22:29 | `--ignore-scripts` 绕过 | ✅ 527 包安装成功 |
| 22:30 | 打包 node_modules | ✅ 97MB |
| 22:33 | 传输到手机 | ✅ 9秒 (12MB/s) |
| 22:33 | 解压并链接 | ✅ openclaw --version 可用 |
| 22:35 | 首次启动 gateway | ❌ Android 服务检查报错 |
| 22:49 | 补丁源码修复服务检查 | ✅ 飞书插件加载 |
| 22:55 | 修复模板文件缺失 | ✅ AGENTS.md 等上传 |
| 23:01 | 飞书配对 | ✅ 配对成功 |
| 23:17 | Gateway 运行正常 | ✅ Web UI 可访问 |

## 踩坑记录

### 1. npm 网络太慢

手机上每个 npm 包下载需要 100-200 秒，500+ 个包需要 1 小时以上。

**解决**: 服务器预下载 `npm install openclaw --ignore-scripts`，打包 97MB 传过去。

### 2. git SSH 依赖 (libsignal-node)

`@whiskeysockets/baileys` 依赖 `libsignal-node` via `ssh://git@github.com/`，手机没有 GitHub SSH key。

尝试的方案:
- `git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"` → 不生效
- 在手机上生成 SSH key → GitHub 连接超时
- 修改 tarball 中的 package.json → 间接依赖不在其中

**解决**: `npm install --ignore-scripts` 跳过所有脚本和 git 解析。

### 3. Android 无 systemd

OpenClaw 检查 `systemd`/`launchd`，Android 没有，直接抛异常。

**解决**: sed 替换 `throw new Error(...)` 为 `return { dummy service }`。

### 4. JavaScript 未引用字符串

源码中 `label: Termux,` 应该是 `label: "Termux",`，导致 `ReferenceError: Termux is not defined`。

**解决**: sed 替换为带引号的字符串。

### 5. SSH 启动的进程会被杀

Termux 中，SSH 会话结束时所有子进程（包括 nohup/setsid/tmux）都会被杀死。

**解决**: 必须从 Termux App 终端直接启动。

### 6. IP 地址变化

DHCP 动态分配 IP，手机重启后 IP 会变。

**临时解决**: `ifconfig wlan0` 查看新 IP。
**长期解决**: 在路由器上给手机分配静态 IP。
