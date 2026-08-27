#
# Via Whitelist Bypass - LSPosed Module
#
# HookEntry: 模块入口，负责在 mark.via 进程中 hook r9.k 的白名单判定方法。
#
# r9.k 是 Via 的白名单判定类（混淆后类名），包含以下关键方法：
#   s(String[], String)Z  — 核心域名匹配器（被 a/c/e/n 内部调用）
#   a(String)Z             — 广告拦截白名单查询
#   c(String)Z             — 白名单查询
#   e(String)Z             — 白名单查询（主入口）
#   n(String)Z             — 白名单查询
#   u(Config)V             — 配置解析器（唯一加载白名单数组 l/m/n/o 的方法）
#
# 白名单数据存储在 Base64 编码的字符串中，通过云端配置键 wlb/wlr/wls/wld 下发：
#   wlb → l[] — 广告拦截白名单：youku.com, iqiyi.com, mgtv.com, qq.com
#   wlr → m[] — 资源嗅探白名单：v.qq.com, youku.com, iqiyi.com, mgtv.com, bilibili.com, ximalaya.com, film.qq.com
#   wls → n[] — 脚本白名单：v.qq.com, film.qq.com
#   wld → o[] — 云端下发专用
#
# 本模块将 s/a/c/e/n/u 全部替换为恒返回 false / 空操作，彻底阻断白名单机制。
#

.class public Lxb/viawb/HookEntry;
.super Ljava/lang/Object;
.implements Lde/robv/android/xposed/IXposedHookLoadPackage;
.source "HookEntry.java"


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

# hookOne: 对 r9.k 的指定方法安装 hook，替换为 Recorder（恒返回 false）
# 参数: clazz - r9.k 的 Class 对象
#       name  - 要 hook 的方法名（"s"/"a"/"c"/"e"/"n"/"u"）
# 返回: true = hook 成功, false = hook 失败（方法不存在等）
.method private static hookOne(Ljava/lang/Class;Ljava/lang/String;)Z
    .registers 5

    :ta
    new-instance v0, Lxb/viawb/Recorder;

    invoke-direct {v0}, Lxb/viawb/Recorder;-><init>()V

    invoke-static {p0, p1, v0}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    :tb
    const/4 v0, 0x1

    return v0

    :tb_catch
    .catch Ljava/lang/Throwable; {:ta .. :tb} :tc

    :tc
    const/4 v0, 0x0

    return v0
.end method

# handleLoadPackage: Xposed 入口，仅对 mark.via 进程生效
# 流程:
#   1. 检查包名是否为 mark.via
#   2. findClass 加载 r9.k
#   3. 对 6 个方法逐一 hookOne
#   4. 成功后通过 XposedBridge.log 输出状态
.method public handleLoadPackage(Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;)V
    .registers 4

    # 仅在 mark.via 进程中执行
    iget-object v0, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->packageName:Ljava/lang/String;

    const-string v1, "mark.via"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v0

    if-nez v0, :pkg_ok

    return-void

    :pkg_ok
    :h_start

    # 加载 r9.k 类
    const-string v0, "r9.k"

    iget-object v1, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->classLoader:Ljava/lang/ClassLoader;

    invoke-static {v0, v1}, Lde/robv/android/xposed/XposedHelpers;->findClass(Ljava/lang/String;Ljava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v0

    # hook 核心域名匹配器
    const-string v1, "s"

    invoke-static {v0, v1}, Lxb/viawb/HookEntry;->hookOne(Ljava/lang/Class;Ljava/lang/String;)Z

    # hook 广告拦截白名单查询
    const-string v1, "a"

    invoke-static {v0, v1}, Lxb/viawb/HookEntry;->hookOne(Ljava/lang/Class;Ljava/lang/String;)Z

    # hook 白名单查询
    const-string v1, "c"

    invoke-static {v0, v1}, Lxb/viawb/HookEntry;->hookOne(Ljava/lang/Class;Ljava/lang/String;)Z

    # hook 白名单查询（主入口，被 c8.s6 / c8.ua 等多处调用）
    const-string v1, "e"

    invoke-static {v0, v1}, Lxb/viawb/HookEntry;->hookOne(Ljava/lang/Class;Ljava/lang/String;)Z

    # hook 白名单查询
    const-string v1, "n"

    invoke-static {v0, v1}, Lxb/viawb/HookEntry;->hookOne(Ljava/lang/Class;Ljava/lang/String;)Z

    # hook 配置解析器 u() — 从源头阻止白名单数组加载
    const-string v1, "u"

    invoke-static {v0, v1}, Lxb/viawb/HookEntry;->hookOne(Ljava/lang/Class;Ljava/lang/String;)Z

    :h_end

    # 输出成功日志（LSPosed 日志中可见）
    const-string v0, "Via WB: whitelist NEUTRALIZED (r9.k 6 methods hooked incl config parser u)"

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    return-void

    :h_end_catch
    .catch Ljava/lang/Throwable; {:h_start .. :h_end} :h_catch

    :h_catch
    move-exception v0

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/Throwable;)V

    return-void
.end method
