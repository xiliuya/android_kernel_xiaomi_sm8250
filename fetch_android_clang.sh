#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "❌ 错误: 请传入 Clang 版本号！"
    echo "用法示例: $0 clang-r488907  或  $0 r488907"
    exit 1
fi

RAW_VER="$1"
if [[ "$RAW_VER" =~ ^clang- ]]; then
    CLANG_VER="$RAW_VER"
else
    CLANG_VER="clang-$RAW_VER"
fi

TARGET_DIR="android-clang/$CLANG_VER"
echo "🚀 开始高速下载 Android Clang 工具链: ${CLANG_VER}..."

mkdir -p "$TARGET_DIR"

# 直接利用 Google Git 归档接口流式下载并解压
TAR_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/${CLANG_VER}.tar.gz"

if ! curl -sSL "$TAR_URL" | tar -xz -C "$TARGET_DIR"; then
    echo "⚠️  从 'main' 分支获取失败，尝试从 'master' 分支下载..."
    TAR_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/${CLANG_VER}.tar.gz"
    curl -sSL "$TAR_URL" | tar -xz -C "$TARGET_DIR"
fi

CLANG_BIN="./${TARGET_DIR}/bin/clang"

if [ -f "$CLANG_BIN" ]; then
    echo -e "\n✅ 高速解压完成！"
    echo "----------------------------------------"
    "$CLANG_BIN" --version
    echo "----------------------------------------"
    echo "绝对路径: $(pwd)/${TARGET_DIR}"
else
    echo "❌ 错误: 解压后未找到 ${CLANG_VER} 的二进制文件，请检查版本号！"
    exit 1
fi
