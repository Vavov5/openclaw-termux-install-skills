---
name: openclaw-termux
description: Install and configure OpenClaw on an Android phone via Termux. Use when the user wants to run OpenClaw on Android, deploy to phone, set up Termux OpenClaw, or run the agent gateway on a mobile device. Covers Termux environment setup, npm installation (including workarounds for slow networks and git SSH issues), gateway configuration, Feishu channel setup, and keeping the gateway alive in background.
---

# OpenClaw on Termux (Android)

Install, configure, and run OpenClaw on Android via Termux.

## Prerequisites

- **Termux** installed on the target Android device
- SSH access to the phone: `ssh u0_a309@<phone_ip> -p 8022` (password: `passwd`)
- Node.js installed in Termux (`pkg install nodejs`)
- Python3 installed in Termux (`pkg install python`)

## Installation

### Option A: Direct npm install (slow network, may fail)

```bash
npm install -g openclaw
```

On slow networks (Termux), each package can take 3+ minutes. Expect 30-60 min total.

### Option B: Pre-download and transfer (recommended)

If npm is too slow on the phone or git SSH dependencies fail:

1. **On the server**, install with `--ignore-scripts` to skip native/git deps:
   ```bash
   mkdir /tmp/openclaw-pack && cd /tmp/openclaw-pack
   npm init -y
   npm install openclaw --ignore-scripts --legacy-peer-deps
   ```

2. **Strip docs/tests** to reduce size:
   ```bash
   cd node_modules
   find . -name "*.md" -not -name "package.json" -delete
   find . -name "README*" -delete
   find . -name "*.map" -delete
   find . -name "test" -type d -exec rm -rf {} + 2>/dev/null
   ```

3. **Pack and transfer** (~97MB):
   ```bash
   tar czf openclaw-for-phone.tar.gz node_modules/ package.json package-lock.json
   scp openclaw-for-phone.tar.gz phone:~/
   ```

4. **On the phone**, extract and link:
   ```bash
   mkdir ~/openclaw-install && tar xzf ~/openclaw-for-phone.tar.gz -C ~/openclaw-install/
   ln -sf ~/openclaw-install/node_modules/.bin/openclaw ~/../usr/bin/openclaw
   openclaw --version
   ```

### Known Issue: git SSH dependency (libsignal-node)

The `@whiskeysockets/baileys` package depends on `libsignal-node` via git SSH URL. If this fails:

- On the server: `git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"`
- Use `--ignore-scripts` to skip git resolution entirely

### Known Issue: Android gateway service check

OpenClaw checks for `systemd`/`launchd` which don't exist on Android. Patch the source:

```bash
sed -i 's/throw new Error(`Gateway service install not supported on ${process.platform}`)/return { name: "dummy", install: async ()=>{}, start: async ()=>{}, restart: async ()=>{}, stop: async ()=>{}, uninstall: async ()=>{}, describe: ()=>"dummy" }/g' \
  ~/openclaw-install/node_modules/openclaw/dist/service-*.js \
  ~/openclaw-install/node_modules/openclaw/dist/daemon-cli.js
```

Also fix unquoted `Termux` string literals in the same files:

```bash
sed -i 's/label: Termux,/label: "Termux",/g; s/loadedText: running,/loadedText: "running",/g; s/notLoadedText: stopped,/notLoadedText: "stopped",/g' \
  ~/openclaw-install/node_modules/openclaw/dist/service-*.js
```

## Configuration

Config file: `~/.openclaw/openclaw.json`

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "<YOUR_API_KEY>",
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
          "appId": "<FEISHU_APP_ID>",
          "appSecret": "<FEISHU_APP_SECRET>",
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
      "allowedOrigins": ["http://localhost:18789", "http://127.0.0.1:18789"],
      "allowInsecureAuth": true
    }
  }
}
```

After editing config, run `openclaw doctor --fix` to auto-migrate format.

## Workspace Templates

If the Control UI errors with "Missing workspace template", copy templates from the server:

```bash
# From server, transfer templates to phone
scp -r <server_openclaw_path>/docs/reference/templates/* phone:~/.openclaw/workspace/
```

Required template files: `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`, `HEARTBEAT.md`, `BOOTSTRAP.md`, `BOOT.md`

## Running the Gateway

### Critical: Must start from Termux App (not SSH)

Starting via SSH will cause the process to die when SSH disconnects. Always start from the **Termux App terminal** directly:

```bash
# In Termux App
termux-wake-lock          # Prevent Android from killing the process
openclaw gateway run      # Start gateway in foreground
```

Use `openclaw gateway run` (foreground mode), NOT `openclaw gateway start` (daemon mode, unsupported on Android).

### Verifying

From another device on the same network:

```bash
curl http://<phone_ip>:18789/     # Should return HTML
```

### Feishu Pairing

First Feishu message triggers a pairing request:

```
Pairing code: XXXXXXXX
Ask the bot owner to approve with:
openclaw pairing approve feishu XXXXXXXX
```

Approve via SSH:
```bash
openclaw pairing approve feishu XXXXXXXX
```

## Transferring Skills

To migrate workspace skills to the phone:

```bash
# On server, pack skills
cd ~/.openclaw/workspace/skills
tar czf workspace-skills.tar.gz skill1 skill2 skill3

# Transfer and extract
scp workspace-skills.tar.gz phone:~/
# On phone
tar xzf ~/workspace-skills.tar.gz -C ~/.openclaw/workspace/skills/
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Gateway dies after SSH disconnect | Process is child of SSH daemon | Start from Termux App, not SSH |
| `termux-wake-lock` not found | termux-api not installed | `pkg install termux-api` |
| npm install fails on git SSH | libsignal-node git dependency | Use `--ignore-scripts` or set git HTTPS |
| "Missing workspace template" | Templates not copied | Copy `docs/reference/templates/*` |
| Port not accessible on LAN | `bind` set to loopback | Set `gateway.bind: "lan"` |
| Feishu not responding | Gateway not running | Check `pgrep -af openclaw-gateway` |
| Config invalid after update | Format changed | Run `openclaw doctor --fix` |
