#
# Hooker: 恒返回 Boolean.FALSE
# 适用: r9.k 的 s/a/c/e/n 判定方法 → 恒 false → 白名单永不命中
# 要点: intercept() 返回值 = 被 hook 方法的最终返回值（无 setResult）
#
.class public Lcom/via/whitelistbypass/MainHook$FalseHooker;
.super Ljava/lang/Object;

# interfaces
.implements Lio/github/libxposed/api/XposedInterface$Hooker;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method


# virtual methods
# Object intercept(Chain chain) -> Boolean.FALSE
.method public intercept(Lio/github/libxposed/api/XposedInterface$Chain;)Ljava/lang/Object;
    .registers 2

    sget-object v0, Ljava/lang/Boolean;->FALSE:Ljava/lang/Boolean;

    return-object v0
.end method
