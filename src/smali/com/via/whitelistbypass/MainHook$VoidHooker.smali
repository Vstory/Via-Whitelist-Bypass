#
# Hooker: 空操作（返回 null）
# 适用: r9.k 的 u 配置解析器 (Lr9/a;)V → 返回 null → 原方法不执行
#       白名单数组 l/m/n/o 永不填充 → 所有判定天然 false
# 要点: void 方法 intercept() 必须返回 null
#
.class public Lcom/via/whitelistbypass/MainHook$VoidHooker;
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
# Object intercept(Chain chain) -> null
.method public intercept(Lio/github/libxposed/api/XposedInterface$Chain;)Ljava/lang/Object;
    .registers 2

    const/4 v0, 0x0

    return-object v0
.end method
