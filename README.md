# Via Whitelist Bypass

LSPosed 模块，解除 Via 浏览器内置的国内视频网站白名单机制。

## 作用

Via 内置了白名单，位于白名单内的网站将受到以下限制：

| 限制类型 | 受影响的域名 |
|---|---|
| 广告拦截 | youku.com, iqiyi.com, mgtv.com, qq.com |
| 资源嗅探 | v.qq.com, youku.com, iqiyi.com, mgtv.com, bilibili.com, ximalaya.com, film.qq.com |
| 浏览器脚本 | v.qq.com, film.qq.com |

本模块通过 hook Via 内部的白名单判定类 `r9.k`，绕过上述全部限制。

## 工作原理

### 白名单存储

白名单以 Base64 编码硬编码在 Via 的 `r9.k` 类中，通过云端配置键 `wlb`/`wlr`/`wls` 可远程覆盖：

| 云端键 | 对应功能 | Base64 默认值（解码后） |
|---|---|---|
| `wlb` | 广告拦截白名单 | youku.com, iqiyi.com, mgtv.com, qq.com |
| `wlr` | 资源嗅探白名单 | v.qq.com, youku.com, iqiyi.com, mgtv.com, bilibili.com, ximalaya.com, film.qq.com |
| `wls` | 脚本白名单 | v.qq.com, film.qq.com |

### Hook 策略

模块 hook `r9.k` 类的 6 个方法：

| 方法 | 作用 |
|---|---|
| `s(String[], String)` | 核心域名匹配器，所有判定方法的底层实现 |
| `a(String)` | 广告拦截白名单查询 |
| `c(String)` | 白名单查询 |
| `e(String)` | 白名单查询（主入口，被多处调用） |
| `n(String)` | 白名单查询 |
| `u(Config)` | **配置解析器** — 唯一给白名单数组装数据的方法 |

`s/a/c/e/n` 五个方法全部替换为恒返回 `false`（不在白名单中）；`u()` 替换为空操作（从源头阻止白名单数据加载）。

## 要求

- Android 8.0+（API 26）
- LSPosed / Xposed 框架
- Via 浏览器（`mark.via`）

## 安装

1. 从 [Releases](../../releases) 下载最新 APK
2. 安装 APK
3. 在 LSPosed 中启用模块，作用域选择 `mark.via`
4. 强制停止 Via 后重新打开

## 验证

在 LSPosed 日志中搜索 `VWB`，应看到：

```
Via WB: whitelist NEUTRALIZED (r9.k 6 methods hooked incl config parser u)
```

- 出现此日志 = hook 成功
- 出现异常堆栈 = 需要适配新版本（Via 更新导致类名变化）

## 从源码构建

### 环境准备

```bash
# 安装 Java
apt-get update && apt-get install -y --no-install-recommends openjdk-17-jdk-headless wget

# 下载 smali 汇编器及其依赖
mkdir -p tools
wget -O tools/smali.jar   https://repo1.maven.org/maven2/org/smali/smali/2.5.2/smali-2.5.2.jar
wget -O tools/dexlib2.jar https://repo1.maven.org/maven2/org/smali/dexlib2/2.5.2/dexlib2-2.5.2.jar
wget -O tools/util.jar    https://repo1.maven.org/maven2/org/smali/util/2.5.2/util-2.5.2.jar
wget -O tools/jcommander.jar https://repo1.maven.org/maven2/com/beust/jcommander/1.72/jcommander-1.72.jar
wget -O tools/guava.jar   https://repo1.maven.org/maven2/com/google/guava/guava/31.1-jre/guava-31.1-jre.jar
wget -O tools/antlr.jar   https://repo1.maven.org/maven2/org/antlr/antlr-runtime/3.5.2/antlr-runtime-3.5.2.jar
```

### 编译

```bash
# 汇编 smali → dex
java -cp "tools/smali.jar:tools/dexlib2.jar:tools/util.jar:tools/jcommander.jar:tools/guava.jar:tools/antlr.jar" \
  org.jf.smali.Main assemble src/smali -o classes.dex

# 将 classes.dex、AndroidManifest.xml（二进制 AXML）、assets/xposed_init 打包为 APK
# AndroidManifest.xml 需通过 aapt2 或 MT 管理器从 XML 编译为二进制 AXML 格式
# 然后用 MT 管理器或 apksigner 签名
```

> **注意**：`AndroidManifest.xml` 必须是编译后的二进制 AXML 格式，不能直接使用纯文本 XML。
> 推荐使用 [MT 管理器](https://binmt.cc) 或 [apktool](https://apktool.org) 进行编译和签名。

## 技术细节

| 项目 | 内容 |
|---|---|
| 大小 | 8.6 KB |
| 类数量 | 2（HookEntry + Recorder） |
| 使用的 API | `findClass`、`hookAllMethods`、`XposedBridge.log` |
| 签名 | V1 + V2 + V3 |

### 逆向发现过程

白名单类名被 R8 混淆为 `r9.k`，域名列表以 Base64 编码存储防止明文搜索。通过追踪云端配置端点 `https://c.viayoo.com/api/frontend` 的解析逻辑，定位到解析函数 `u()` 和存储字段 `wlb`/`wlr`/`wls`，最终确认白名单的完整域名列表与 BetterVia 公开的完全一致。

## 与 BetterVia 的区别

BetterVia 是修改版 Via 浏览器 APK，通过直接修改源码中的白名单数组实现。本项目是独立的 LSPosed 模块，运行时 hook，不修改 Via 本身，可通过 LSPosed 按需启用/禁用。

## 许可

仅供学习研究使用。
