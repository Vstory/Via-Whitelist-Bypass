#!/bin/bash
#
# Via Whitelist Bypass - 一键发布脚本
#
# 用法:
#   ./publish.sh                          交互式输入
#   GH_USER=xxx GH_TOKEN=xxx ./publish.sh 通过环境变量传入（推荐）
#
# 前置要求:
#   - git
#   - curl 或 wget
#   - GitHub Personal Access Token（repo 权限）
#     获取地址: https://github.com/settings/tokens
#

set -e

# ========== 配置 ==========

VERSION="v3.0.0"
RELEASE_NAME="Via Whitelist Bypass $VERSION (api102)"
APK_FILE="ViaWhitelistBypass_3.0.0(10013).apk"

# APK 可能在项目根目录或 release/ 目录
if [ ! -f "$APK_FILE" ] && [ -f "release/$APK_FILE" ]; then
    APK_FILE="release/$APK_FILE"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ========== 检查工具 ==========

command -v git >/dev/null 2>&1 || { echo "❌ 需要 git，请先安装"; exit 1; }

if command -v curl >/dev/null 2>&1; then
    HTTP="curl"
elif command -v wget >/dev/null 2>&1; then
    HTTP="wget"
else
    echo "❌ 需要 curl 或 wget"; exit 1
fi

# ========== 获取凭证 ==========

if [ -z "$GH_USER" ]; then
    read -rp "GitHub 用户名: " GH_USER
fi

if [ -z "$GH_TOKEN" ]; then
    read -rsp "GitHub Token: " GH_TOKEN
    echo
fi

if [ -z "$GH_TOKEN" ]; then
    echo "❌ Token 不能为空"; exit 1
fi

REPO="${GH_REPO:-ViaWhitelistBypass}"

# ========== GitHub API 请求 ==========

github_api() {
    local method="$1"
    local url="$2"
    local data="$3"

    if [ "$HTTP" = "curl" ]; then
        curl -s -X "$method" \
            -H "Authorization: token $GH_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url"
    else
        wget -q -O - --method="$method" \
            --header="Authorization: token $GH_TOKEN" \
            --header="Accept: application/vnd.github.v3+json" \
            --header="Content-Type: application/json" \
            --body-data="$data" \
            "$url"
    fi
}

# ========== Step 1: 初始化 Git ==========

echo ""
echo "📦 [1/4] 初始化 Git 仓库..."

if [ ! -d ".git" ]; then
    git init -b main
fi

# .gitignore 已存在，跳过
git add .
git commit -m "Release $VERSION" --allow-empty 2>/dev/null || true

# ========== Step 2: 创建 GitHub 仓库 ==========

echo "🌐 [2/4] 创建 GitHub 仓库..."

RESP=$(github_api POST "https://api.github.com/user/repos" \
    "{\"name\":\"$REPO\",\"auto_init\":false,\"description\":\"LSPosed module to bypass Via browser whitelist\"}")

# 检查是否已存在
if echo "$RESP" | grep -q '"already_exists"'; then
    echo "   ℹ️  仓库已存在，继续..."
else
    echo "   ✅ 仓库创建成功"
fi

# ========== Step 3: 推送代码 ==========

echo "🚀 [3/4] 推送代码..."

# 移除旧 remote（如果有）
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$REPO.git"

git push -u origin main --force

# ========== Step 4: 创建 Release ==========

echo "📋 [4/4] 创建 Release..."

# 创建 Release
RELEASE_RESP=$(github_api POST "https://api.github.com/repos/$GH_USER/$REPO/releases" \
    "{\"tag_name\":\"$VERSION\",\"name\":\"$RELEASE_NAME\",\"body\":\"## Features\n\n- 8.6KB 极简 LSPosed 模块 (libxposed API 102)\n- 解除 Via 浏览器国内视频网站白名单限制\n- Hook r9.k 的 s/a/c/e/n/u 六个方法 (按方法名匹配)\n- 支持 Android 8.0+ / LSPosed\n\n## 安装\n\n1. 下载 APK 文件\n2. 安装到设备\n3. 在 LSPosed 中启用，作用域选择 mark.via\n4. 强制停止 Via 后重新打开\"}")

# 从响应中提取 release id 和 upload_url
RELEASE_ID=$(echo "$RELEASE_RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

if [ -z "$RELEASE_ID" ]; then
    echo "   ⚠️  Release 创建失败，尝试使用已有 Release..."
    RELEASE_ID=$(github_api GET "https://api.github.com/repos/$GH_USER/$REPO/releases/tags/$VERSION" "" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
fi

# 上传 APK（如果有）
if [ -n "$RELEASE_ID" ] && [ -f "$APK_FILE" ]; then
    echo "   📤 上传 APK..."
    if [ "$HTTP" = "curl" ]; then
        curl -s -X POST \
            -H "Authorization: token $GH_TOKEN" \
            -H "Content-Type: application/vnd.android.package-archive" \
            --data-binary @"$APK_FILE" \
            "https://uploads.github.com/repos/$GH_USER/$REPO/releases/$RELEASE_ID/assets?name=$APK_FILE"
    else
        wget -q -O - --method=POST \
            --header="Authorization: token $GH_TOKEN" \
            --header="Content-Type: application/vnd.android.package-archive" \
            --body-file="$APK_FILE" \
            "https://uploads.github.com/repos/$GH_USER/$REPO/releases/$RELEASE_ID/assets?name=$APK_FILE"
    fi
    echo "   ✅ APK 上传完成"
else
    echo "   ⚠️  未找到 APK 文件，跳过上传"
fi

# ========== 完成 ==========

echo ""
echo "🎉 发布完成!"
echo ""
echo "   仓库: https://github.com/$GH_USER/$REPO"
echo "   Release: https://github.com/$GH_USER/$REPO/releases/tag/$VERSION"
echo ""
echo "📦 下载地址:"
echo "   https://github.com/$GH_USER/$REPO/releases/download/$VERSION/$APK_FILE"
