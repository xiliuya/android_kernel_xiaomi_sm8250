#!/bin/bash

# 遇到错误立即退出
set -e

# 参数检查
if [ -z "$1" ]; then
	echo "用法: $0 <导出 Header 路径> [Kernel Build/Output 路径 (O=out)] [Kernel Src 路径]"
	echo "示例 (普通模式):  $0 /tmp/my-headers"
	echo "示例 (O=out模式): $0 ./headers ./out ."
	exit 1
fi

DEST_DIR="$(realpath "$1")"
BUILD_DIR="${2:-$(pwd)}"
BUILD_DIR="$(realpath "$BUILD_DIR")"
SRC_DIR="${3:-$BUILD_DIR}"
SRC_DIR="$(realpath "$SRC_DIR")"

# 自动获取并映射架构 (支持环境变量 ARCH 或 CARCH)
ARCH="${ARCH:-${CARCH:-$(uname -m)}}"
case "$ARCH" in
x86_64 | amd64) karch="x86" ;;
aarch64 | arm64) karch="arm64" ;;
armv*) karch="arm" ;;
*) karch="$ARCH" ;;
esac

echo "=========================================="
echo "开始导出内核 Headers (Android / Arch 终极修正版)"
echo "源码目录 (Src)   : $SRC_DIR"
echo "构建目录 (Build) : $BUILD_DIR"
echo "导出目录 (Dest)  : $DEST_DIR"
echo "目标架构 (Arch)  : $karch"
echo "=========================================="

# 1. 检查必要文件
if [ ! -f "$BUILD_DIR/.config" ]; then
	echo "错误: 在 $BUILD_DIR 下未找到 .config 文件！"
	exit 1
fi

mkdir -p "$DEST_DIR"

# 辅助拷贝函数
copy_file_if_exists() {
	local target_dir="$1"
	shift
	for file in "$@"; do
		if [ -f "$BUILD_DIR/$file" ]; then
			install -Dt "$DEST_DIR/$target_dir" -m644 "$BUILD_DIR/$file"
		elif [ -f "$SRC_DIR/$file" ]; then
			install -Dt "$DEST_DIR/$target_dir" -m644 "$SRC_DIR/$file"
		fi
	done
}

# 纯 grep 检查内核配置函数（避免依赖未生成的 scripts/config）
is_config_enabled() {
	local config_name="$1"
	grep -q "^${config_name}=y" "$BUILD_DIR/.config" 2>/dev/null
}

echo "[1/8] 复制核心构建文件（强制使用源码根目录原生 Makefile）..."
# 关键修复：强制取 SRC_DIR 的原始 Makefile/Kconfig，防止使用 out/ 里的 mkmakefile 重定向包装器
install -m644 "$SRC_DIR/Makefile" "$DEST_DIR/Makefile"
install -m644 "$SRC_DIR/Kconfig" "$DEST_DIR/Kconfig"

# 提取其他生成和配置文件
copy_file_if_exists "." .config Module.symvers System.map localversion.* version vmlinux tools/bpf/bpftool/vmlinux.h vmlinux.h
copy_file_if_exists "kernel" kernel/Makefile
copy_file_if_exists "arch/$karch" arch/$karch/Makefile

echo "[2/8] 复制构建脚本 (scripts) 与工具..."
# O=out 时优先使用 BUILD_DIR 下编译好的 scripts 二进制工具
if [ -d "$BUILD_DIR/scripts" ]; then
	cp -t "$DEST_DIR" -a "$BUILD_DIR/scripts"
elif [ -d "$SRC_DIR/scripts" ]; then
	cp -t "$DEST_DIR" -a "$SRC_DIR/scripts"
fi

if [ -f "$DEST_DIR/scripts/gdb/vmlinux-gdb.py" ]; then
	ln -srf "$DEST_DIR/scripts/gdb/vmlinux-gdb.py" "$DEST_DIR/vmlinux-gdb.py" 2>/dev/null || true
fi

echo "[3/8] 安装编译辅助工具 (objtool, resolve_btfids)..."
if is_config_enabled "CONFIG_HAVE_STACK_VALIDATION"; then
	[ -f "$BUILD_DIR/tools/objtool/objtool" ] && install -Dt "$DEST_DIR/tools/objtool" "$BUILD_DIR/tools/objtool/objtool"
fi

if is_config_enabled "CONFIG_DEBUG_INFO_BTF_MODULES"; then
	[ -f "$BUILD_DIR/tools/bpf/resolve_btfids/resolve_btfids" ] && install -Dt "$DEST_DIR/tools/bpf/resolve_btfids" "$BUILD_DIR/tools/bpf/resolve_btfids/resolve_btfids"
fi

echo "[4/8] 复制 include 核心头文件及 asm-offsets.s (自动展开软链接)..."
# 使用 cp -aL 解开高通/Android 头文件中的相对软链接 (如 msm_ion.h)
cp -aL "$SRC_DIR/include" "$DEST_DIR/" 2>/dev/null || cp -a "$SRC_DIR/include" "$DEST_DIR/"
if [ "$BUILD_DIR" != "$SRC_DIR" ] && [ -d "$BUILD_DIR/include" ]; then
	cp -aL "$BUILD_DIR/include/"* "$DEST_DIR/include/" 2>/dev/null || cp -a "$BUILD_DIR/include/"* "$DEST_DIR/include/"
fi

mkdir -p "$DEST_DIR/arch/$karch"
cp -aL "$SRC_DIR/arch/$karch/include" "$DEST_DIR/arch/$karch/" 2>/dev/null || cp -a "$SRC_DIR/arch/$karch/include" "$DEST_DIR/arch/$karch/"
if [ "$BUILD_DIR" != "$SRC_DIR" ] && [ -d "$BUILD_DIR/arch/$karch/include" ]; then
	mkdir -p "$DEST_DIR/arch/$karch/include"
	cp -aL "$BUILD_DIR/arch/$karch/include/"* "$DEST_DIR/arch/$karch/include/" 2>/dev/null || cp -a "$BUILD_DIR/arch/$karch/include/"* "$DEST_DIR/arch/$karch/include/"
fi

copy_file_if_exists "arch/$karch/kernel" "arch/$karch/kernel/asm-offsets.s"

echo "[5/8] 安装驱动及网络特定补充头文件 (Drivers & Net)..."
install_headers_pattern() {
	local pattern="$1"
	local dest_sub="$2"

	for base in "$SRC_DIR" "$BUILD_DIR"; do
		if compgen -G "$base/$pattern" >/dev/null; then
			mkdir -p "$DEST_DIR/$dest_sub"
			cp -f $base/$pattern "$DEST_DIR/$dest_sub/" 2>/dev/null || true
		fi
	done
}

install_headers_pattern "drivers/md/*.h" "drivers/md"
install_headers_pattern "net/mac80211/*.h" "net/mac80211"
install_headers_pattern "drivers/media/i2c/msp3400-driver.h" "drivers/media/i2c"
install_headers_pattern "drivers/media/usb/dvb-usb/*.h" "drivers/media/usb/dvb-usb"
install_headers_pattern "drivers/media/dvb-frontends/*.h" "drivers/media/dvb-frontends"
install_headers_pattern "drivers/media/tuners/*.h" "drivers/media/tuners"
install_headers_pattern "drivers/iio/common/hid-sensors/*.h" "drivers/iio/common/hid-sensors"

echo "[6/8] 递归复制全树 Kconfig 配置文件..."
(cd "$SRC_DIR" && find . -name 'Kconfig*' -exec install -Dm644 {} "$DEST_DIR/{}" \;)
if [ "$BUILD_DIR" != "$SRC_DIR" ]; then
	(cd "$BUILD_DIR" && find . -name 'Kconfig*' -exec install -Dm644 {} "$DEST_DIR/{}" \;)
fi

echo "[7/8] 检查并复制 Rust 相关组件 (如启用)..."
if is_config_enabled "CONFIG_RUST"; then
	if [ -d "$BUILD_DIR/rust" ]; then
		mkdir -p "$DEST_DIR/rust"
		compgen -G "$BUILD_DIR/rust/*.rmeta" >/dev/null && cp "$BUILD_DIR/rust/"*.rmeta "$DEST_DIR/rust/"
		compgen -G "$BUILD_DIR/rust/*.so" >/dev/null && cp "$BUILD_DIR/rust/"*.so "$DEST_DIR/rust/"
	fi
fi

echo "[8/8] 执行清理：移除无用架构、断裂软链接及 loose .o..."
for arch in "$DEST_DIR"/arch/*/; do
	[[ "$arch" = */"$karch"/ ]] && continue
	rm -rf "$arch"
done

rm -rf "$DEST_DIR/Documentation"

echo "清理断裂软链接..."
find -L "$DEST_DIR" -type l -delete 2>/dev/null || true

echo "清理中间 .o 文件..."
find "$DEST_DIR" -type f -name '*.o' ! -name 'vmlinux' -delete 2>/dev/null || true

echo "=========================================="
echo "🎉 Kernel Headers 提取完成！"
echo "导出路径: $DEST_DIR"
echo "=========================================="
