#!/bin/bash
#
# analyze_via.sh - 分析新版 Via APK，自动定位白名单类（混淆名）
#
# 用法:
#   ./tools/analyze_via.sh <via.apk>              # 扫描并输出类名
#   ./tools/analyze_via.sh <via.apk> --update     # 扫描 + 自动更新 MainHook.smali
#   ./tools/analyze_via.sh <via.apk> --build      # 扫描 + 更新 + 构建 APK
#
# 依赖:
#   - Java (baksmali 需要)
#   - baksmali (自动下载到 tools/)
#
# 原理:
#   白名单类 r9.k 的稳定特征（R8 重跑不变）：
#   - 有 ≥4 个 [Ljava/lang/String; 字段（对应 wlb/wlr/wls/wld 四个白名单数组）
#   - 有多个 (Ljava/lang/String;)Z 方法（a/c/e/n 判定方法）
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
BAKSMALI_JAR="$TOOLS_DIR/baksmali-2.5.2.jar"

# ========== 参数解析 ==========
if [ $# -lt 1 ]; then
    echo "用法: $0 <via.apk> [--update] [--build]"
    echo ""
    echo "  --update  扫描后自动更新 HookEntry.smali 中的类名"
    echo "  --build   扫描 + 更新 + 构建模块 APK"
    exit 1
fi

APK_PATH="$1"
DO_UPDATE=false
DO_BUILD=false
shift

while [ $# -gt 0 ]; do
    case "$1" in
        --update) DO_UPDATE=true ;;
        --build)  DO_UPDATE=true; DO_BUILD=true ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK 文件不存在: $APK_PATH"
    exit 1
fi

# ========== 1. 下载 baksmali ==========
echo "[1/5] 检查 baksmali..."
if [ ! -f "$BAKSMALI_JAR" ]; then
    echo "      下载 baksmali..."
    mkdir -p "$TOOLS_DIR"
    wget -q -O "$BAKSMALI_JAR" \
        "https://repo1.maven.org/maven2/org/smali/baksmali/2.5.2/baksmali-2.5.2.jar"
    echo "      下载完成"
else
    echo "      baksmali 已就绪"
fi

# ========== 2. 反编译 ==========
echo "[2/5] 反编译 APK..."
WORK_DIR="$TOOLS_DIR/.tmp_scan"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
java -jar "$BAKSMALI_JAR" d "$APK_PATH" -o "$WORK_DIR/smali" 2>/dev/null
FILE_COUNT=$(find "$WORK_DIR/smali" -name "*.smali" | wc -l)
echo "      反编译完成: ${FILE_COUNT} 个 smali 文件"

# ========== 3. 特征码扫描 ==========
echo "[3/5] 特征码扫描..."
echo ""
echo "  特征条件："
echo "    1. 有 ≥4 个 [Ljava/lang/String; 字段（白名单数组）"
echo "    2. 有多个 (Ljava/lang/String;)Z 方法（判定方法）"
echo ""

# 找出有 4+ 个 String[] 字段的类
CANDIDATES=""
for smali_file in $(find "$WORK_DIR/smali" -name "*.smali" ! -name "*\$*" | head -5000); do
    # 统计 String[] 字段数量
    STR_ARRAY_COUNT=$(grep -c '\[Ljava/lang/String;' "$smali_file" 2>/dev/null || echo 0)

    if [ "$STR_ARRAY_COUNT" -ge 4 ]; then
        # 提取类名（从 .class 行）
        CLASS_LINE=$(head -1 "$smali_file")
        CLASS_NAME=$(echo "$CLASS_LINE" | sed 's/\.class.*L//;s/;.*//;s|/|.|g')

        # 检查是否有多个 (String)→boolean 方法
        BOOL_METHOD_COUNT=$(grep -cE '\.method.*\(Ljava/lang/String;\)Z' "$smali_file" 2>/dev/null || echo 0)

        if [ "$BOOL_METHOD_COUNT" -ge 2 ]; then
            CANDIDATES="$CANDIDATES$CLASS_NAME|$STR_ARRAY_COUNT|$BOOL_METHOD_COUNT\n"
        fi
    fi
done

# ========== 4. 输出结果 ==========
echo "[4/5] 扫描结果"
echo ""

if [ -z "$CANDIDATES" ]; then
    echo "  ❌ 未找到匹配的类！"
    echo "  可能原因："
    echo "    - Via 版本变化导致类结构改变"
    echo "    - APK 格式不支持"
    echo ""
    rm -rf "$WORK_DIR"
    exit 1
fi

echo "  候选类（String[]字段数 | (String)→boolean方法数）："
echo "  ─────────────────────────────────────────"
echo "$CANDIDATES" | while IFS='|' read -r class str_count bool_count; do
    [ -z "$class" ] && continue
    echo "  $class  (${str_count} 个 String[] 字段, ${bool_count} 个判定方法)"
done
echo ""

# 取第一个候选（最可能是白名单类）
BEST_CLASS=$(echo -e "$CANDIDATES" | head -1 | cut -d'|' -f1)
OLD_CLASS=$(grep -o 'const-string v3, "[^"]*"' "$SCRIPT_DIR/src/smali/com/via/whitelistbypass/MainHook.smali" | head -1 | grep -o '"[^"]*"' | tr -d '"')

echo "  ✅ 推荐类名: $BEST_CLASS"
echo "  📌 当前模块类名: $OLD_CLASS"
echo ""

# ========== 5. 自动更新 ==========
if [ "$DO_UPDATE" = true ]; then
    if [ "$BEST_CLASS" = "$OLD_CLASS" ]; then
        echo "[5/5] 类名未变化，无需更新"
    else
        echo "[5/5] 自动更新 MainHook.smali..."
        echo "      $OLD_CLASS → $BEST_CLASS"

        # 转换为 smali 格式的类名（点号→斜杠，加 L 前缀和分号）
        SMALI_CLASS="L$(echo "$BEST_CLASS" | tr '.' '/');"

        # 替换 MainHook.smali 中的类名
        sed -i "s|const-string v3, \"$OLD_CLASS\"|const-string v3, \"$BEST_CLASS\"|g" \
            "$SCRIPT_DIR/src/smali/com/via/whitelistbypass/MainHook.smali"

        # 同时更新 Recorder.smali 中的 VWB hit 日志（如果有类名引用的话）
        # Recorder 中没有硬编码类名，无需更新

        echo "      ✅ MainHook.smali 已更新"

        if [ "$DO_BUILD" = true ]; then
            echo ""
            echo "      开始构建..."
            cd "$SCRIPT_DIR"
            chmod +x build.sh
            # 用 smali 汇编（如果 build.sh 可用）
            if [ -f "$TOOLS_DIR/smali.jar" ]; then
                mkdir -p build
                SMALI_CP="$TOOLS_DIR/smali.jar:$TOOLS_DIR/dexlib2.jar:$TOOLS_DIR/util.jar:$TOOLS_DIR/jcommander.jar:$TOOLS_DIR/guava.jar:$TOOLS_DIR/antlr.jar"
                java -cp "$SMALI_CP" org.jf.smali.Main assemble src/smali -o build/classes.dex 2>/dev/null
                cd build && rm -f ViaWhitelistBypass_unsigned.apk
                zip -q ViaWhitelistBypass_unsigned.apk classes.dex
                echo "      ✅ 构建完成: build/ViaWhitelistBypass_unsigned.apk"
                echo "      ⚠️  需要手动签名后安装"
            else
                echo "      ⚠️  smali.jar 未找到，请运行 build.sh 构建"
            fi
        fi
    fi
else
    echo "提示: 添加 --update 参数可自动更新类名"
    echo "      添加 --build 参数可自动更新 + 构建"
fi

# 清理
rm -rf "$WORK_DIR"
