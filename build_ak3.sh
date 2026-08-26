#!/bin/bash

# 发生错误时立即终止脚本执行
set -e

# 参数检查
if [ $# -lt 2 ]; then
    echo "❌ 错误: 参数不足！"
    echo "用法: $0 <AnyKernel3_Git地址> <Image文件路径> [输出ZIP文件名]"
    echo "示例: $0 https://github.com/osm0sis/AnyKernel3.git /path/to/Image kernel-installer.zip"
    exit 1
fi

AK3_REPO="$1"
IMAGE_PATH="$2"
OUTPUT_ZIP="${3:-anykernel3-installer.zip}"
WORK_DIR="AK3_tmp_$(date +%s)"

# 校验 Image 文件是否存在
if [ ! -f "$IMAGE_PATH" ]; then
    echo "❌ 错误: 找不到 Image 文件: $IMAGE_PATH"
    exit 1
fi

echo "🚀 开始处理 AnyKernel3 打包..."

# 1. 克隆 AnyKernel3 仓库
echo "📥 正在克隆 AnyKernel3 仓库..."
git clone --depth=1 "$AK3_REPO" "$WORK_DIR"

# 2. 复制 Image 到工作目录
echo "📋 正在复制 Kernel 镜像文件..."
cp "$IMAGE_PATH" "$WORK_DIR/Image"

# 3. 进入目录并打包 ZIP
echo "📦 正在生成 ZIP 包..."
cd "$WORK_DIR"
# 打包所有文件，排除 git 隐藏目录及压缩包本身
zip -r9 "../$OUTPUT_ZIP" . -x "*.git*" "*.zip"
cd ..

# 4. 清理临时文件夹
echo "🧹 正在清理临时文件..."
rm -rf "$WORK_DIR"

echo "✅ 完成！刷机包已打包为: $OUTPUT_ZIP"
