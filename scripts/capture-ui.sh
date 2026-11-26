#!/bin/bash
# SnowAir Mac · 真机 UI 截图脚本
# 运行前提：GitHub self-hosted runner 已注册，并以 GUI 会话（LaunchAgent）方式运行，
#          且 runner 进程已获「屏幕录制」权限（系统设置 → 隐私与安全性 → 屏幕录制）。
# 用法： ./scripts/capture-ui.sh <输出目录>
# 输出： annotations.png（标注窗口+7种图形）、menubar.png（菜单栏常驻图标）

set -euo pipefail

OUT_DIR="${1:-./ui-shots}"
mkdir -p "$OUT_DIR"

# 1) 定位 Package.swift（兼容只推子目录或整个工作区两种布局）
if [ -f Package.swift ]; then
  PKG_DIR=.
elif [ -f SnowAir-Mac/Package.swift ]; then
  PKG_DIR=SnowAir-Mac
else
  echo "::error::找不到 Package.swift"
  exit 1
fi
cd "$PKG_DIR"

# 2) 编译调试版
echo "==> swift build"
swift build

BIN_PATH="$(swift build --show-bin-path)/SnowAirMac"
if [ ! -x "$BIN_PATH" ]; then
  echo "::error::未找到可执行文件: $BIN_PATH"
  exit 1
fi
echo "==> app: $BIN_PATH"

# 3) 以演示模式启动（合成图，无需屏幕录制权限即可出现标注窗口）
echo "==> 启动演示模式"
SNOWAIR_UI_DEMO=annotation "$BIN_PATH" >"$OUT_DIR/app.log" 2>&1 &
APP_PID=$!
sleep 4

if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "::error::App 启动即退出，日志如下："
  cat "$OUT_DIR/app.log"
  exit 1
fi

# 4) 抓全屏（含菜单栏图标 + 标注窗口 + 7 种图形标注）
#    -x 静音、-t png 指定格式；macOS 13+ 直接写目标路径
SCREEN="$OUT_DIR/screen-full.png"
screencapture -x -t png "$SCREEN"

# 校验截图非空白：文件大小 > 20KB 才认为有效（纯色空白图通常 < 20KB）
SIZE=$(stat -f%z "$SCREEN")
echo "==> 全屏截图大小: ${SIZE} bytes"
if [ "$SIZE" -lt 20000 ]; then
  echo "::warning::截图疑似空白（可能缺少屏幕录制权限），请检查 runner 权限设置"
fi

# 5) 关闭演示进程
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true

echo "==> 完成，截图目录: $OUT_DIR"
ls -la "$OUT_DIR"
