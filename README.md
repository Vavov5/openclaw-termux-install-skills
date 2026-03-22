# OpenClaw Termux Install Skills 📱🦞

> 一键在 Android 手机上安装 OpenClaw，让你的旧手机发光发热！

抽屉里的旧手机别吃灰了——装上 OpenClaw，它就是你的随身 AI 助手。支持飞书、Web UI、股票分析等全功能，24 小时在线。

## ✨ 功能

- 📱 在任意 Android 手机上运行 OpenClaw Gateway
- 💬 支持飞书/Telegram/Discord 等消息通道
- 🌐 局域网内访问 Control UI（Web 管理界面）
- 🤖 支持多种 AI 模型（OpenRouter、OpenAI 等）
- 🛠️ 内置 Agent Skill，一句话自动部署
- 🔋 termux-wake-lock 保持后台常驻

## 📋 前置要求

| 项目 | 要求 |
|------|------|
| Android | 7.0+ |
| Termux | F-Droid 版本（[下载](https://f-droid.org/packages/com.termux/)）|
| 存储空间 | 至少 500MB 可用 |
| 网络 | 手机和服务器同一局域网 |

> ⚠️ 不要用 Google Play 版本的 Termux，已停止更新。

---

## 🚀 安装方式

### 方式一：Agent Skill 安装（推荐）

如果你已经有一台运行 OpenClaw 的服务器，可以通过 Agent 自动完成安装。

#### 1. 安装 Skill

将本仓库的 `skills/openclaw-termux` 目录复制到服务器的 workspace skills 中：

```bash
cp -r skills/openclaw-termux ~/.openclaw/workspace/skills/
```



#### 2. 准备手机

在手机上安装 Termux 并完成基础配置：

```bash
# 在 Termux 中执行
pkg update && pkg upgrade -y
pkg install nodejs python openssh git termux-api -y

# 设置 SSH 密码
passwd
# 输入密码

# 启动 SSH
sshd

# 查看手机 IP
ifconfig wlan0 | grep inet
```

#### 3. 告诉 Agent 执行安装

```
@小龙虾 帮我在这台手机上安装 OpenClaw
手机 IP: 192.168.1.100
SSH 端口: 8022
用户名: u0_a309
密码: passwd
飞书 App ID: cli_xxxxxxxxxx
飞书 App Secret: xxxxxxxxxxxx
```

Agent 会自动完成：
- 在服务器预下载 OpenClaw（绕过手机慢网络）
- 打包传输到手机
- 解压并创建命令行链接
- 修复 Android 兼容性问题
- 配置模型和飞书通道
- 启动 Gateway

---

### 方式二：手动安装

适合没有服务器 Agent 的场景，全程在手机和电脑上手动操作。

#### Step 1: 安装 Termux 基础环境

```bash
pkg update && pkg upgrade -y
pkg install nodejs python openssh git curl termux-api -y

# 设置 SSH 密码
passwd

# 启动 SSH
sshd

# 查看 IP
ifconfig wlan0 | grep inet
```

#### Step 2: 安装 OpenClaw

由于手机网络较慢，推荐在电脑上预下载后传输。

**在电脑上：**

```bash
# 创建临时目录
mkdir /tmp/openclaw-pack && cd /tmp/openclaw-pack
npm init -y

# 跳过脚本安装（避免 git SSH 依赖问题）
npm install openclaw --ignore-scripts --legacy-peer-deps

# 精简打包
cd node_modules
find . -name "*.md" -not -name "package.json" -delete
find . -name "README*" -delete
find . -name "*.map" -delete
find . -name "test" -type d -exec rm -rf {} + 2>/dev/null
find . -name "tests" -type d -exec rm -rf {} + 2>/dev/null

cd /tmp/openclaw-pack
tar czf openclaw-for-phone.tar.gz node_modules/ package.json package-lock.json
# 约 97MB
```

**传输到手机：**

```bash
scp -P 8022 openclaw-for-phone.tar.gz u0_a309@<手机IP>:~/
```

**在手机上：**

```bash
# 解压
mkdir ~/openclaw-install
tar xzf ~/openclaw-for-phone.tar.gz -C ~/openclaw-install/

# 创建命令链接
ln -sf ~/openclaw-install/node_modules/.bin/openclaw ~/../usr/bin/openclaw

# 验证
openclaw --version
```

#### Step 3: 修复 Android 兼容性

OpenClaw 的服务管理功能依赖 systemd/launchd，Android 不支持。需要打补丁：

```bash
# 修复 "Gateway service install not supported on android"
sed -i 's/throw new Error(`Gateway service install not supported on ${process.platform}`)/return { name: "dummy", install: async ()=>{}, start: async ()=>{}, restart: async ()=>{}, stop: async ()=>{}, uninstall: async ()=>{}, describe: ()=>"dummy" }/g' \
  ~/openclaw-install/node_modules/openclaw/dist/service-*.js \
  ~/openclaw-install/node_modules/openclaw/dist/daemon-cli.js

# 修复 "Termux is not defined" (JavaScript 字符串未引用)
sed -i 's/label: Termux,/label: "Termux",/g; s/loadedText: running,/loadedText: "running",/g; s/notLoadedText: stopped,/notLoadedText: "stopped",/g' \
  ~/openclaw-install/node_modules/openclaw/dist/service-*.js
```

#### Step 4: 配置 OpenClaw

创建配置文件 `~/.openclaw/openclaw.json`：

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "sk-or-v1-你的API密钥",
        "models": [
          {
            "id": "xiaomi/mimo-v2-pro",
            "name": "Xiaomi MiMo V2 Pro",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 262144,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "dmPolicy": "pairing",
      "accounts": {
        "main": {
          "appId": "cli_你的飞书AppID",
          "appSecret": "你的飞书AppSecret",
          "botName": "AI助手",
          "streaming": true,
          "blockStreaming": false
        }
      }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "allowedOrigins": ["http://localhost:18789"],
      "allowInsecureAuth": true
    }
  }
}
```

> 💡 参考 `config/openclaw-example.json` 获取完整配置模板。

写入后执行：

```bash
openclaw doctor --fix
```

#### Step 5: 复制 Workspace 模板

如果 Web UI 报 "Missing workspace template" 错误：

```bash
mkdir -p ~/.openclaw/workspace
```

将以下文件放入 `~/.openclaw/workspace/`：

- `AGENTS.md`
- `SOUL.md`
- `USER.md`
- `TOOLS.md`
- `IDENTITY.md`
- `HEARTBEAT.md`
- `BOOTSTRAP.md`
- `BOOT.md`

可以从 OpenClaw 安装目录获取模板：

```bash
cp ~/openclaw-install/node_modules/openclaw/docs/reference/templates/* ~/.openclaw/workspace/
```

#### Step 6: 启动 Gateway

```bash
# 在 Termux App 终端中（不要通过 SSH！）

# 防止休眠杀进程
termux-wake-lock

# 启动 Gateway（前台模式）
openclaw gateway run
```

> ⚠️ **必须从 Termux App 直接启动，不能从 SSH 启动！**
> 
> Termux 的 SSH 会在断开时杀死所有子进程。只有从 Termux App 启动的进程才能存活。

启动后访问：`http://<手机IP>:18789`

#### Step 7: 飞书配对

首次通过飞书发消息会触发配对：

```
Pairing code: XXXXXXXX
openclaw pairing approve feishu XXXXXXXX
```

通过 SSH 批准配对：

```bash
ssh u0_a309@<手机IP> -p 8022
openclaw pairing approve feishu XXXXXXXX
```

---

## 🔧 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Gateway 启动后 SSH 断开就死 | 进程属于 SSH 会话 | 从 Termux App 启动 |
| `npm install` 极慢 | 手机网络差 | 用电脑预下载后传输 |
| `git SSH` 权限拒绝 | 没有 GitHub SSH key | `npm install --ignore-scripts` |
| `Termux is not defined` | JS 源码字符串未引用 | 运行 Step 3 的 sed 命令 |
| `service install not supported` | Android 无 systemd | 运行 Step 3 的 sed 命令 |
| 模板文件缺失 | 没复制 workspace 模板 | 运行 Step 5 |
| 飞书无响应 | Gateway 没在运行 | `pgrep -af openclaw-gateway` |
| IP 变了连不上 | DHCP 动态分配 | `ifconfig wlan0` 查看 |
| `termux-wake-lock` 未找到 | 没装 termux-api | `pkg install termux-api` |

---

## 📁 项目结构

```
openclaw-termux-install-skills/
├── README.md                  # 本文件
├── LICENSE                    # MIT 协议
├── scripts/
│   ├── install.sh             # 一键安装脚本
│   └── patch-android.sh       # Android 兼容性补丁
├── config/
│   └── openclaw-example.json  # 配置模板
├── skills/
│   └── openclaw-termux/       # Agent Skill（自动化安装）
│       └── SKILL.md
└── docs/
    └── install-log.md         # 安装踩坑记录
```

---

## 🔑 关键发现

### 为什么不能从 SSH 启动？

Android 上的 Termux 使用 proot 模拟 Linux 环境。SSH（sshd）作为 Android 服务运行，但当 SSH 会话结束时，Android 会杀死该会话的所有子进程——包括通过 `nohup`、`setsid`、`tmux` 启动的进程。

只有从 **Termux App 终端** 启动的进程才属于 Termux 应用本身，不受 SSH 会话生命周期影响。

### 为什么要预下载？

Termux 在 Android 上的网络性能受限：
- 每个 npm 包下载约 100-200 秒
- 完整安装 500+ 包需要 1 小时+
- 网络波动容易导致安装中断

在服务器上预下载（约 5 分钟），打包传输（约 10 秒），效率提升 100 倍。

### 为什么要打补丁？

OpenClaw 设计为桌面/服务器应用，依赖 systemd（Linux）或 launchd（macOS）管理服务。Android 没有这些系统服务管理器，所以需要修改源码跳过检查。

---

## 📝 已测试设备

| 设备 | 系统 | 状态 |
|------|------|------|
| OPPO A5 Pro (PEDM00) | Android 14 | ✅ 正常 |

欢迎提交 PR 添加更多测试设备。

---

## 🙏 致谢

- [OpenClaw](https://github.com/openclaw/openclaw) - 多平台 AI 网关
- [Termux](https://termux.dev/) - Android 终端模拟器

## 📄 License

MIT
