#!/bin/bash
#
# Via Whitelist Bypass - 构建脚本
#
# 依赖: openjdk-17-jdk-headless, wget
#
# 用法: chmod +x build.sh && ./build.sh
#
# 产出: build/ViaWhitelistBypass_unsigned.apk（未签名）
#       需要使用 MT 管理器或 apksigner 签名后方可安装
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TOOLS_DIR="tools"
BUILD_DIR="build"
SRC_DIR="src"

# ========== 1. 下载依赖 ==========

echo "[1/4] 检查构建工具..."

if [ ! -f "$TOOLS_DIR/smali.jar" ]; then
    echo "      下载 smali 汇编器及依赖..."
    mkdir -p "$TOOLS_DIR"
    wget -q -O "$TOOLS_DIR/smali.jar"       "https://repo1.maven.org/maven2/org/smali/smali/2.5.2/smali-2.5.2.jar"
    wget -q -O "$TOOLS_DIR/dexlib2.jar"     "https://repo1.maven.org/maven2/org/smali/dexlib2/2.5.2/dexlib2-2.5.2.jar"
    wget -q -O "$TOOLS_DIR/util.jar"        "https://repo1.maven.org/maven2/org/smali/util/2.5.2/util-2.5.2.jar"
    wget -q -O "$TOOLS_DIR/jcommander.jar"  "https://repo1.maven.org/maven2/com/beust/jcommander/1.72/jcommander-1.72.jar"
    wget -q -O "$TOOLS_DIR/guava.jar"       "https://repo1.maven.org/maven2/com/google/guava/guava/31.1-jre/guava-31.1-jre.jar"
    wget -q -O "$TOOLS_DIR/antlr.jar"       "https://repo1.maven.org/maven2/org/antlr/antlr-runtime/3.5.2/antlr-runtime-3.5.2.jar"
    echo "      下载完成"
else
    echo "      工具已就绪"
fi

SMALI_CP="$TOOLS_DIR/smali.jar:$TOOLS_DIR/dexlib2.jar:$TOOLS_DIR/util.jar:$TOOLS_DIR/jcommander.jar:$TOOLS_DIR/guava.jar:$TOOLS_DIR/antlr.jar"

# ========== 2. 编译 ==========

echo "[2/4] 编译 smali → classes.dex..."
mkdir -p "$BUILD_DIR"
java -cp "$SMALI_CP" org.jf.smali.Main assemble "$SRC_DIR/smali" -o "$BUILD_DIR/classes.dex"
DEX_SIZE=$(wc -c < "$BUILD_DIR/classes.dex")
echo "      classes.dex: ${DEX_SIZE} bytes"

# ========== 3. 打包 ==========

echo "[3/4] 打包未签名 APK..."
cd "$BUILD_DIR"
rm -f ViaWhitelistBypass_unsigned.apk
zip -q ViaWhitelistBypass_unsigned.apk classes.dex
cd "$SCRIPT_DIR"

# 注意: AndroidManifest.xml 需要以二进制 AXML 格式打包
#       此脚本仅生成 dex 部分，完整的 APK 需要:
#       1. 使用 MT 管理器创建新 APK，写入 AndroidManifest.xml (AXML)
#       2. 或使用 aapt2 编译 manifest 后合并
#       3. 或使用 apktool 打包
#
#       推荐方案: 在 MT 管理器中操作（参见 README.md）

echo "      classes.dex 已生成: $BUILD_DIR/classes.dex"

# ========== 4. 完成 ==========

echo "[4/4] 构建完成!"
echo ""
echo "下一步:"
echo "  1. 在 MT 管理器中新建一个 APK"
echo "  2. 导入 AndroidManifest.xml (AXML)、classes.dex、assets/xposed_init"
echo "  3. 签名后即可安装"
echo ""
echo "AndroidManifest.xml 内容 (XML，需编译为 AXML):"
echo "---"
cat << 'MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    android:versionCode="10010"
    android:versionName="2.0.1"
    package="com.via.whitelistbypass">
    <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="34"/>
    <application android:label="Via Whitelist Bypass" android:allowBackup="false">
        <meta-data android:name="xposedmodule" android:value="true"/>
        <meta-data android:name="xposedminversion" android:value="93"/>
        <meta-data android:name="xposeddescription"
            android:value="Neutralize mark.via video-site whitelist (r9.k 6 methods)"/>
        <meta-data android:name="xposedscope" android:value="mark.via"/>
    </application>
</manifest>
MANIFEST
echo "---"
echo ""
echo "assets/xposed_init 内容:"
echo "  xb.viawb.HookEntry"
