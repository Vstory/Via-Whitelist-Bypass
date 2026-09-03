#
# ============================================================
# Via Whitelist Bypass - libxposed API 102 入口类
# 由传统 Xposed API (xb.viawb.HookEntry) 重构而来
# 逻辑: 按方法名 hook r9.k 的全部同名方法 (代替旧 hookAllMethods)
#   s/a/c/e/n → FalseHooker (恒 false, 解除白名单判定)
#   u         → VoidHooker  (空操作, 阻止配置解析器加载白名单)
# ============================================================
# 生命周期: onModuleLoaded → onPackageReady → installHooks
# 热重载:   onHotReloading 返回 true + onHotReloaded unhook旧handle + installHooks 重装
# 注意:
#   - 禁止调用传统 de.robv.android.xposed.* API
#   - Class.forName 的 initialize 必须 false（触发 <clinit> 会让 APP 崩溃!）
#   - 方法名匹配: r9.k 的 a/c/e/n/s/u 在各 Via 版本保持一致（混淆类名会变, 方法名稳定）
#
.class public Lcom/via/whitelistbypass/MainHook;
.super Lio/github/libxposed/api/XposedModule;

# 保存被 hook 应用的 classLoader（热重载 fallback 用，主路径从旧 hook handle 取）
.field private mAppClassLoader:Ljava/lang/ClassLoader;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Lio/github/libxposed/api/XposedModule;-><init>()V

    return-void
.end method

# 按方法名 hook 目标类的所有同名方法, 返回成功数量
# 等价旧 API 的 XposedBridge.hookAllMethods; 兼容 s/a/c/e/n/u 的不同参数签名
.method private hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I
    .registers 14

    # v0 = 成功计数
    const/4 v0, 0x0

    :try_start
    # Class.forName(className, false, classLoader) — initialize 必须 false!
    const/4 v1, 0x0

    invoke-static {p2, v1, p1}, Ljava/lang/Class;->forName(Ljava/lang/String;ZLjava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v1

    # Method[] methods = clazz.getDeclaredMethods()
    invoke-virtual {v1}, Ljava/lang/Class;->getDeclaredMethods()[Ljava/lang/reflect/Method;

    move-result-object v2

    # 遍历 methods: for (int i = 0; i < methods.length; i++)
    array-length v3, v2

    const/4 v4, 0x0

    :loop
    if-ge v4, v3, :done

    aget-object v5, v2, v4

    # m.getName().equals(methodName)
    invoke-virtual {v5}, Ljava/lang/reflect/Method;->getName()Ljava/lang/String;

    move-result-object v6

    invoke-virtual {v6, p3}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v6

    if-eqz v6, :next

    # hook(method) -> HookBuilder (XposedInterfaceWrapper 方法, invoke-virtual)
    invoke-virtual {p0, v5}, Lio/github/libxposed/api/XposedInterfaceWrapper;->hook(Ljava/lang/reflect/Executable;)Lio/github/libxposed/api/XposedInterface$HookBuilder;

    move-result-object v6

    # builder.setExceptionMode(ExceptionMode.PROTECTIVE) -> HookBuilder (接口方法, invoke-interface)
    sget-object v7, Lio/github/libxposed/api/XposedInterface$ExceptionMode;->PROTECTIVE:Lio/github/libxposed/api/XposedInterface$ExceptionMode;

    invoke-interface {v6, v7}, Lio/github/libxposed/api/XposedInterface$HookBuilder;->setExceptionMode(Lio/github/libxposed/api/XposedInterface$ExceptionMode;)Lio/github/libxposed/api/XposedInterface$HookBuilder;

    move-result-object v6

    # builder.intercept(hooker) -> HookHandle
    invoke-interface {v6, p4}, Lio/github/libxposed/api/XposedInterface$HookBuilder;->intercept(Lio/github/libxposed/api/XposedInterface$Hooker;)Lio/github/libxposed/api/XposedInterface$HookHandle;

    # count++
    add-int/lit8 v0, v0, 0x1

    :next
    add-int/lit8 v4, v4, 0x1

    goto :loop

    :done
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_ignore

    :catch_ignore
    return v0
.end method

# 安装全部 hooks（onPackageReady 与 onHotReloaded 共用）
# 返回真实 hook 成功数量（诊断日志用）
.method private installHooks(Ljava/lang/ClassLoader;)I
    .registers 10

    # 复用 Hooker 实例（无状态, 可多个方法共用）
    new-instance v1, Lcom/via/whitelistbypass/MainHook$FalseHooker;

    invoke-direct {v1}, Lcom/via/whitelistbypass/MainHook$FalseHooker;-><init>()V

    new-instance v2, Lcom/via/whitelistbypass/MainHook$VoidHooker;

    invoke-direct {v2}, Lcom/via/whitelistbypass/MainHook$VoidHooker;-><init>()V

    # 总计数
    const/4 v0, 0x0

    # 目标类: r9.k = Via 白名单类（混淆名, Via 更新后可能变化 → 用 tools/analyze_via.sh 扫描更新）
    const-string v3, "r9.k"

    # s: 核心域名匹配器 (所有判定的底层) → false
    const-string v4, "s"

    invoke-direct {p0, p1, v3, v4, v1}, Lcom/via/whitelistbypass/MainHook;->hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I

    move-result v5

    add-int/2addr v0, v5

    # a: 资源嗅探白名单 (wlr) ★核心目标 → false
    const-string v4, "a"

    invoke-direct {p0, p1, v3, v4, v1}, Lcom/via/whitelistbypass/MainHook;->hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I

    move-result v5

    add-int/2addr v0, v5

    # c: 下载功能白名单 (wld) → false
    const-string v4, "c"

    invoke-direct {p0, p1, v3, v4, v1}, Lcom/via/whitelistbypass/MainHook;->hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I

    move-result v5

    add-int/2addr v0, v5

    # e: 脚本白名单 (wls) → false
    const-string v4, "e"

    invoke-direct {p0, p1, v3, v4, v1}, Lcom/via/whitelistbypass/MainHook;->hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I

    move-result v5

    add-int/2addr v0, v5

    # n: 广告豁免白名单 (wlb) → false
    const-string v4, "n"

    invoke-direct {p0, p1, v3, v4, v1}, Lcom/via/whitelistbypass/MainHook;->hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I

    move-result v5

    add-int/2addr v0, v5

    # u: 配置解析器 (阻止白名单数据加载) → 空操作
    const-string v4, "u"

    invoke-direct {p0, p1, v3, v4, v2}, Lcom/via/whitelistbypass/MainHook;->hookMethod(Ljava/lang/ClassLoader;Ljava/lang/String;Ljava/lang/String;Lio/github/libxposed/api/XposedInterface$Hooker;)I

    move-result v5

    add-int/2addr v0, v5

    return v0
.end method


# virtual methods
.method public onModuleLoaded(Lio/github/libxposed/api/XposedModuleInterface$ModuleLoadedParam;)V
    .registers 5

    # log(Log.INFO, "ViaWB", "api102 module loaded")
    const/4 v0, 0x4

    const-string v1, "ViaWB"

    const-string v2, "api102 module loaded"

    invoke-virtual {p0, v0, v1, v2}, Lio/github/libxposed/api/XposedInterfaceWrapper;->log(ILjava/lang/String;Ljava/lang/String;)V

    return-void
.end method

.method public onPackageReady(Lio/github/libxposed/api/XposedModuleInterface$PackageReadyParam;)V
    .registers 7

    # 获取目标包 classLoader 并保存（热重载 fallback 用）
    invoke-interface {p1}, Lio/github/libxposed/api/XposedModuleInterface$PackageReadyParam;->getClassLoader()Ljava/lang/ClassLoader;

    move-result-object v0

    iput-object v0, p0, Lcom/via/whitelistbypass/MainHook;->mAppClassLoader:Ljava/lang/ClassLoader;

    # 安装全部 hooks, 拿到真实 hook 数量
    invoke-direct {p0, v0}, Lcom/via/whitelistbypass/MainHook;->installHooks(Ljava/lang/ClassLoader;)I

    move-result v1

    # count == 0 → 子进程/无白名单类, 不打印 NEUTRALIZED 误导
    if-nez v1, :neutralized

    # log(Log.INFO, "ViaWB", "Via WB: subprocess, no whitelist class (r9.k) skipped")
    const/4 v2, 0x4

    const-string v3, "ViaWB"

    const-string v4, "Via WB: subprocess, no whitelist class (r9.k) skipped"

    invoke-virtual {p0, v2, v3, v4}, Lio/github/libxposed/api/XposedInterfaceWrapper;->log(ILjava/lang/String;Ljava/lang/String;)V

    return-void

    :neutralized
    # log "Via WB: whitelist NEUTRALIZED (r9.k N methods hooked incl config parser u)"
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "Via WB: whitelist NEUTRALIZED (r9.k "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v3, " methods hooked incl config parser u)"

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    # log(Log.INFO, "ViaWB", msg)
    const/4 v3, 0x4

    const-string v4, "ViaWB"

    invoke-virtual {p0, v3, v4, v2}, Lio/github/libxposed/api/XposedInterfaceWrapper;->log(ILjava/lang/String;Ljava/lang/String;)V

    return-void
.end method

# 允许热重载（接口默认返回 false, 不覆写会拒绝热重载请求）
.method public onHotReloading(Lio/github/libxposed/api/XposedModuleInterface$HotReloadingParam;)Z
    .registers 3

    const/4 v0, 0x1

    return v0
.end method

# 热重载完成后: 从旧 hook handle 取 classLoader → unhook 全部旧 hooks → installHooks 重装
.method public onHotReloaded(Lio/github/libxposed/api/XposedModuleInterface$HotReloadedParam;)V
    .registers 8

    # 1. 从旧 hook handle 取 app classLoader（热重载不会重放 onPackageReady, 新实例字段为 null）
    const/4 v0, 0x0

    invoke-interface {p1}, Lio/github/libxposed/api/XposedModuleInterface$HotReloadedParam;->getOldHookHandles()Ljava/util/List;

    move-result-object v1

    invoke-interface {v1}, Ljava/util/List;->isEmpty()Z

    move-result v2

    if-nez v2, :try_handle

    const/4 v2, 0x0

    invoke-interface {v1, v2}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Lio/github/libxposed/api/XposedInterface$HookHandle;

    invoke-interface {v1}, Lio/github/libxposed/api/XposedInterface$HookHandle;->getExecutable()Ljava/lang/reflect/Executable;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/reflect/Executable;->getDeclaringClass()Ljava/lang/Class;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/Class;->getClassLoader()Ljava/lang/ClassLoader;

    move-result-object v0

    :try_handle
    # 2. unhook 全部旧 hooks
    invoke-interface {p1}, Lio/github/libxposed/api/XposedModuleInterface$HotReloadedParam;->getOldHookHandles()Ljava/util/List;

    move-result-object v1

    invoke-interface {v1}, Ljava/util/List;->iterator()Ljava/util/Iterator;

    move-result-object v1

    :loop_unhook
    invoke-interface {v1}, Ljava/util/Iterator;->hasNext()Z

    move-result v2

    if-eqz v2, :done_unhook

    invoke-interface {v1}, Ljava/util/Iterator;->next()Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Lio/github/libxposed/api/XposedInterface$HookHandle;

    invoke-interface {v2}, Lio/github/libxposed/api/XposedInterface$HookHandle;->unhook()V

    goto :loop_unhook

    :done_unhook
    # 3. fallback: 用保存的 mAppClassLoader
    if-nez v0, :have_cl

    iget-object v0, p0, Lcom/via/whitelistbypass/MainHook;->mAppClassLoader:Ljava/lang/ClassLoader;

    :have_cl
    # 4. 拿不到 classLoader 就不重装
    if-nez v0, :install

    return-void

    :install
    # 5. 重装 hooks
    invoke-direct {p0, v0}, Lcom/via/whitelistbypass/MainHook;->installHooks(Ljava/lang/ClassLoader;)I

    # log(Log.INFO, "ViaWB", "hot reloaded, hooks reinstalled")
    const/4 v1, 0x4

    const-string v2, "ViaWB"

    const-string v3, "hot reloaded, hooks reinstalled"

    invoke-virtual {p0, v1, v2, v3}, Lio/github/libxposed/api/XposedInterfaceWrapper;->log(ILjava/lang/String;Ljava/lang/String;)V

    return-void
.end method
