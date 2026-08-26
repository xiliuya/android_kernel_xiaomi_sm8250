#!/bin/bash
set -e

# ==========================================
# 通用 GitHub Release 附件下载/提取函数
# 参数:
#   $1 - 仓库名称 (例: "owner/repo")
#   $2 - 匹配文件名的正则表达式/关键字 (例: "\.apk" 或 "kptools-linux")
#   $3 - 保存的文件名 (例: "APatch.zip" 或 "kptools-linux")
# ==========================================
download_github_asset() {
    local repo="$1"
    local pattern="$2"
    local output_name="$3"

    echo "🔍 正在获取 $repo 的最新 Release 信息..."

    # 获取最新发布中匹配条件的下载链接
    local download_url
    download_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" \
      | grep -oP '"browser_download_url": "\K[^"]*'"${pattern}"'[^"]*' \
      | head -n 1)

    if [ -z "$download_url" ]; then
        echo "❌ 获取失败：在 $repo 中未找到匹配 '$pattern' 的文件"
        return 1
    fi

    echo "🔗 下载链接: $download_url"
    echo "📥 正在下载至 $output_name..."

    # 执行下载 (-L 跟踪重定向, -o 指定输出文件名)
    curl -L "$download_url" -o "$output_name"
    echo "✅ 下载成功: $output_name"
}

# ==========================================
# 任务 1: 获取 APatch 的 kpimg
# ==========================================
download_github_asset "bmax121/APatch" "\.apk" "APatch.zip"

unzip -p APatch.zip assets/kpimg > kpimg
rm -f APatch.zip

echo "✅ 提取 kpimg 完成！"
echo "----------------------------------------"

# ==========================================
# 任务 2: 获取 KernelPatch 的 kptools-linux
# ==========================================
download_github_asset "bmax121/KernelPatch" "kptools-linux" "kptools-linux"
chmod +x kptools-linux

echo "✅ kptools-linux 准备就绪并已赋予执行权限！"

