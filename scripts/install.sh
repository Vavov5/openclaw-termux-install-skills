#!/bin/bash
# OpenClaw Termux 安装脚本
# 用法: bash install.sh

set -e

echo "🦞 OpenClaw Termux Installer"
echo "============================"

# 检查 Termux 环境
if [ ! -d "/data/data/com.termux" ]; then
    echo "❌ 此脚本需要在 Termux 中运行"
    exit 1
fi

# 安装依赖
echo "📦 安装依赖..."
pkg update -y
pkg install nodejs python openssh git curl termux-api -y

# 检查是否有预下载的包
if [ -f ~/openclaw-for-phone.tar.gz ]; then
    echo "📦 发现预下载包，解压中..."
    mkdir -p ~/openclaw-install
    tar xzf ~/openclaw-for-phone.tar.gz -C ~/openclaw-install/
else
    echo "⬇️ 未发现预下载包，尝试从 npm 安装（可能很慢）..."
    npm install -g openclaw 2>&1 || {
        echo "❌ npm 安装失败"
        echo "💡 建议在电脑上预下载后传输："
        echo "   npm install openclaw --ignore-scripts"
        echo "   然后 scp 传输 openclaw-for-phone.tar.gz"
        exit 1
    }
fi

# 创建命令链接
echo "🔗 创建命令链接..."
ln -sf ~/openclaw-install/node_modules/.bin/openclaw ~/../usr/bin/openclaw 2>/dev/null || true

# 验证安装
echo "✅ 验证安装..."
openclaw --version || {
    echo "❌ openclaw 命令不可用"
    exit 1
}

# 应用 Android 补丁
echo "🔧 应用 Android 兼容性补丁..."
OC_DIST=~/openclaw-install/node_modules/openclaw/dist

sed -i 's/throw new Error(`Gateway service install not supported on ${process.platform}`)/return { name: "dummy", install: async ()=>{}, start: async ()=>{}, restart: async ()=>{}, stop: async ()=>{}, uninstall: async ()=>{}, describe: ()=>"dummy" }/g' \
  $OC_DIST/service-*.js \
  $OC_DIST/daemon-cli.js 2>/dev/null

sed -i 's/label: Termux,/label: "Termux",/g; s/loadedText: running,/loadedText: "running",/g; s/notLoadedText: stopped,/notLoadedText: "stopped",/g' \
  $OC_DIST/service-*.js 2>/dev/null

# 复制 workspace 模板
echo "📄 复制 workspace 模板..."
mkdir -p ~/.openclaw/workspace
if [ -d ~/openclaw-install/node_modules/openclaw/docs/reference/templates ]; then
    cp ~/openclaw-install/node_modules/openclaw/docs/reference/templates/* ~/.openclaw/workspace/ 2>/dev/null
fi

echo ""
echo "🎉 安装完成！"
echo ""
echo "下一步："
echo "  1. 创建配置文件: ~/.openclaw/openclaw.json"
echo "     参考: https://github.com/your-repo/openclaw-termux"
echo "  2. 运行: openclaw doctor --fix"
echo "  3. 启动: termux-wake-lock && openclaw gateway run"
echo ""
echo "⚠️ 必须从 Termux App 启动，不能从 SSH！"
