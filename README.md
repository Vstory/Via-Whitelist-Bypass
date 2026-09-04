# Via Whitelist Bypass

LSPosed / Xposed 模块，解除 Via 浏览器内置的国内视频网站白名单机制，让优酷、爱奇艺、芒果 TV、腾讯视频、B 站等站点恢复资源嗅探等能力。

> ⚠️ 仅针对 **官网版 Via（包名 `mark.via`）**。Google Play 版（`mark.via.gp`）混淆类名/逻辑可能不同，不保证兼容。
> ⚠️ 基于 **libxposed API 102** 重构（v3.x），需要 LSPosed 支持 API 102（1.9+）。

## 🎯 解锁内容

| 白名单 | 配置键 | 解锁后效果 |
|---|---|---|
| 资源嗅探白名单 | `wlr` | **恢复资源嗅探**（嗅探按钮/菜单可用，不再提示"该网站不支持资源嗅探"）★核心目标 |
| 广告拦截豁免白名单 | `wlb` | 命中站点不再豁免广告拦截 |
| 脚本白名单 | `wls` | 脚本/注入行为不再受限 |
| 下载功能白名单 | `wld` | 不再提示"It cannot work on this site." |

启用模块后，以下站点均可正常资源嗅探：

```
v.qq.com  youku.com  iqiyi.com  mgtv.com
bilibili.com  ximalaya.com  film.qq.com
```

## 要求

- Android 8.0+（API 26，api102 要求）
- LSPosed 1.9+（支持 libxposed API 102）
- Via 浏览器官网版（`mark.via`）

## 安装

1. 下载 [Releases](../../releases) 中的 APK
2. 安装 APK
3. LSPosed 中启用模块（作用域自动声明 `mark.via`，staticScope）
4. 强制停止 Via 后重新打开

## 验证

### 方法一：功能验证（推荐）

1. 打开优酷/爱奇艺/腾讯视频/B 站等白名单站点
2. 点击**资源嗅探按钮**或菜单 → 资源嗅探
3. **能打开嗅探页面、列出资源** = 模块生效 ✅
4. 对照：停用模块后，同一站点提示"该网站不支持资源嗅探"或按钮无反应

### 方法二：LSPosed 日志

LSPosed 日志中搜索 `ViaWB` / `Via WB`：

```
Via WB: whitelist NEUTRALIZED (r9.k 6 methods hooked incl config parser u)
```

- **`6 methods hooked` 是真实 hook 数量**（由代码统计输出）
- `6` = 6 个方法全部 hook 成功 ✅；`0` = 全部失败（检查类名是否适配新版 Via）
- 支持热重载：LSPosed 热重载后自动重装 hooks

## 构建

需要：`aapt`、`smali`、`zipalign`、`apksigner`、`keytool`（模板 build.sh 已配置路径）。

```bash
./build.sh          # patch: versionCode+1
./build.sh minor    # minor: 次版本+1
./build.sh major    # major: 主版本+1
./build.sh -k my.keystore   # 自定义签名
```

`build.sh` 自动完成：smali 汇编 → aapt 编译资源（二进制 AXML）→ 打包（resources.arsc Stored 对齐）→ zipalign → apksigner 签名 → verify.sh 验证。

产物：`release/ViaWhitelistBypass_<版本名>(<版本号>).apk`（已签名可安装）。

## Via 版本适配（特征码自动匹配）

当 Via 更新后 R8 混淆名变化（如 `r9.k` → `q8.k`），用特征码扫描工具自动适配：

```bash
# 1. 扫描新版 Via APK，输出白名单类名
./tools/analyze_via.sh via_new.apk

# 2. 扫描 + 自动更新 MainHook.smali 中的类名
./tools/analyze_via.sh via_new.apk --update

# 3. 扫描 + 更新 + 构建模块 APK
./tools/analyze_via.sh via_new.apk --build
```

**依赖**：Java（baksmali 自动下载到 `tools/`）。


## 免责声明

仅供学习与个人使用。使用本模块可能违反目标网站的条款或 Via 的软件许可，请自行承担风险。
