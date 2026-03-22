#!/bin/bash
# OpenClaw Android 兼容性补丁
# 在 Termux 中运行此脚本修复 Android 上的启动问题

set -e

echo "🔧 OpenClaw Android Patch"
echo "========================="

OC_DIST=~/openclaw-install/node_modules/openclaw/dist

if [ ! -d "$OC_DIST" ]; then
    echo "❌ 未找到 OpenClaw 安装目录: $OC_DIST"
    echo "   请先安装 OpenClaw"
    exit 1
fi

# 补丁 1: 修复 "Gateway service install not supported on android"
echo "  [1/2] 修复服务管理器检查..."
MATCHES=$(grep -c "Gateway service install not supported" $OC_DIST/service-*.js $OC_DIST/daemon-cli.js 2>/dev/null | wc -l)
if [ "$MATCHES" -gt 0 ]; then
    sed -i 's/throw new Error(`Gateway service install not supported on ${process.platform}`)/return { name: "dummy", install: async ()=>{}, start: async ()=>{}, restart: async ()=>{}, stop: async ()=>{}, uninstall: async ()=>{}, describe: ()=>"dummy" }/g' \
      $OC_DIST/service-*.js \
      $OC_DIST/daemon-cli.js
    echo "        ✅ 已修复"
else
    echo "        ⏭️ 已修复或无需修复"
fi

# 补丁 2: 修复 "Termux is not defined" (JavaScript 未引用字符串)
echo "  [2/2] 修复未引用的字符串字面量..."
MATCHES=$(grep -c "label: Termux," $OC_DIST/service-*.js 2>/dev/null | grep -v ":0$" | wc -l)
if [ "$MATCHES" -gt 0 ]; then
    sed -i 's/label: Termux,/label: "Termux",/g; s/loadedText: running,/loadedText: "running",/g; s/notLoadedText: stopped,/notLoadedText: "stopped",/g' \
      $OC_DIST/service-*.js
    echo "        ✅ 已修复"
else
    echo "        ⏭️ 已修复或无需修复"
fi

echo ""
echo "🎉 补丁完成！现在可以运行: openclaw gateway run"
