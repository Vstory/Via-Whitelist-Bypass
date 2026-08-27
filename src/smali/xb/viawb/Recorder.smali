#
# Via Whitelist Bypass - LSPosed Module
#
# Recorder: 方法替换体，替换 r9.k 的白名单判定方法，恒返回 Boolean.FALSE。
#
# 被 hook 的方法返回值含义:
#   true  = URL 在白名单中（限制生效）
#   false = URL 不在白名单中（限制不生效）
#
# 本类将所有被 hook 的方法恒返回 false，使 Via 始终认为当前网站不在白名单中。
#
# 首次命中时会输出诊断日志到 LSPosed 日志（tag: VWB），
# 包含被调用的方法名和传入的 URL 参数，用于确认 hook 正常工作。
#

.class public Lxb/viawb/Recorder;
.super Lde/robv/android/xposed/XC_MethodReplacement;
.source "Recorder.java"


# static fields
# 是否已输出过首次命中日志（每个 Via 进程生命周期内仅输出一次）
.field private static hitOnce:Z


# instance fields
# 被 hook 的方法名标识（"s"/"a"/"c"/"e"/"n"/"u"）
.field private final tag:Ljava/lang/String;


# direct methods
.method static constructor <clinit>()V
    .registers 1

    const/4 v0, 0x0

    sput-boolean v0, Lxb/viawb/Recorder;->hitOnce:Z

    return-void
.end method

# 构造函数，参数为被 hook 的方法名标识
.method public constructor <init>()V
    .registers 2

    invoke-direct {p0}, Lde/robv/android/xposed/XC_MethodReplacement;-><init>()V

    const-string v1, "?"

    iput-object v1, p0, Lxb/viawb/Recorder;->tag:Ljava/lang/String;

    return-void
.end method


# virtual methods
# 替换被 hook 方法的执行逻辑，恒返回 Boolean.FALSE
#
# 对于返回 boolean 的方法（s/a/c/e/n）：false = 不在白名单中
# 对于返回 void 的方法（u 配置解析器）：返回值被忽略，等效于空操作
#
# 首次命中时遍历参数列表寻找 String 类型的 URL，
# 输出 "VWB hit:<method> <url>" 到 LSPosed 日志用于诊断。
.method protected replaceHookedMethod(Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;)Ljava/lang/Object;
    .registers 9

    # 仅首次命中时输出诊断日志
    sget-boolean v0, Lxb/viawb/Recorder;->hitOnce:Z

    if-nez v0, :cond_silent

    # 标记已输出过
    const/4 v0, 0x1

    sput-boolean v0, Lxb/viawb/Recorder;->hitOnce:Z

    # 从参数中查找 URL 字符串并输出
    :td_start
    iget-object v1, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->args:[Ljava/lang/Object;

    if-eqz v1, :td_end

    array-length v2, v1

    add-int/lit8 v2, v2, -0x1

    # 从数组末尾向前搜索第一个 String 类型参数（通常是 URL）
    :lp
    if-ltz v2, :td_end

    aget-object v3, v1, v2

    instance-of v4, v3, Ljava/lang/String;

    if-eqz v4, :lp_next

    check-cast v3, Ljava/lang/String;

    # 构建日志消息: "VWB hit:<tag> <url>"
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "VWB hit:"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    iget-object v5, p0, Lxb/viawb/Recorder;->tag:Ljava/lang/String;

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v5, " "

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v3

    invoke-static {v3}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    goto :td_end

    :lp_next
    add-int/lit8 v2, v2, -0x1

    goto :lp

    :td_end
    goto :cond_silent

    :td_catch
    .catch Ljava/lang/Throwable; {:td_start .. :td_end} :td_err

    :td_err
    nop

    :cond_silent
    # 恒返回 Boolean.FALSE（= 不在白名单中）
    sget-object v0, Ljava/lang/Boolean;->FALSE:Ljava/lang/Boolean;

    return-object v0
.end method
