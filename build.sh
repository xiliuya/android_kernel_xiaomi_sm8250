#!/bin/bash

# 获取第 1 个参数作为根目录；若未传入参数，则默认使用 /content
# ${1%/} 自动剥离末尾的斜杠 /，确保路径拼接干净
BASE_DIR="${1:-/content}"
BASE_DIR="${BASE_DIR%/}"

# 校验基础路径是否存在
if [ ! -d "${BASE_DIR}" ]; then
    echo "❌ 错误: 目标根目录 '${BASE_DIR}' 不存在！"
    exit 1
fi

echo "📁 当前工作根目录为: ${BASE_DIR}"

#cd "${BASE_DIR}/kernel_sm8250" || { echo "❌ 无法进入目录 ${BASE_DIR}/kernel_sm8250"; exit 1; }

# 1. 设置环境变量与编译器工具链路径
export PATH="${BASE_DIR}/android-clang/clang-r547379/bin:$PATH"

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

# 日志保存路径
LOG_FILE="${BASE_DIR}/build.log"
ERR_FILE="${BASE_DIR}/build_errors.txt"

# 2. 准备干净的输出目录
rm -rf out
mkdir -p out

# 3. 拼接三份 Config 碎片到 out/.config
cat arch/arm64/configs/vendor/kona-perf_defconfig \
    arch/arm64/configs/vendor/xiaomi/sm8250-common.config \
    arch/arm64/configs/vendor/xiaomi/alioth.config \
    Droidspace.config > out/.config

echo "=== 1. 拼接完成，碎片配置行数 ==="
wc -l out/.config

# 4. 全量展开并补全配置节点
make O=out LLVM=1 olddefconfig

echo "=== 2. olddefconfig 展开完成，最终配置行数 ==="
wc -l out/.config

# 5. 执行内核全量编译
# 2>&1 | tee "${LOG_FILE}" 会将标准输出和标准错误流同时打在终端并存入文件
echo "=== 3. 开始编译内核 (完整日志同步写入 ${LOG_FILE})... ==="
make -j$(nproc) O=out \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    LLVM=1 \
    LLVM_IAS=1 \
    KCFLAGS="-Wno-error" 2>&1 | tee "${LOG_FILE}"

# 6. 检查编译结果并精准提取报错
if [ -f "out/arch/arm64/boot/Image" ]; then
    echo "🎉 内核编译成功！"
    echo "Image 位置: out/arch/arm64/boot/Image"
    [ -f "out/arch/arm64/boot/dtbo.img" ] && echo "DTBO 位置: out/arch/arm64/boot/dtbo.img" 

    # ==================== 新增：打包 Header ====================
    echo "📦 正在打包 Kernel Headers (tar-pkg)..."
    make O=out \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        LLVM=1 \
        LLVM_IAS=1 tarbz2-pkg

    HEADER_TAR=$(find out -maxdepth 1 -name "linux-*.tar.bz2" | head -n 1)
    [ -n "$HEADER_TAR" ] && echo "✅ Headers 打包完成: $HEADER_TAR"
    # ===========================================================
else
    echo ""
    echo "❌ 编译失败！正在从日志中提取关键错误信息..."
    echo "==================== 关键 Error 摘要 ====================" | tee "${ERR_FILE}"
    grep -i -C 3 "error:" "${LOG_FILE}" | tee -a "${ERR_FILE}"
    echo "========================================================"
    echo "💡 完整日志已保存至: ${LOG_FILE}"
    echo "💡 错误提炼已保存至: ${ERR_FILE}"
fi
exit 0
