package com.via.whitelistbypass;

import android.util.Log;

import java.lang.reflect.Executable;
import java.lang.reflect.Method;
import java.util.Iterator;
import java.util.List;

import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedInterfaceWrapper;
import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface;

/**
 * Via Whitelist Bypass — libxposed API 102 入口类
 *
 * 逻辑: 按方法名 hook r9.k 的全部同名方法 (代替旧 hookAllMethods)
 *   s/a/c/e/n → FalseHooker (恒 false, 解除白名单判定)
 *   u         → VoidHooker  (空操作, 阻止配置解析器加载白名单)
 *
 * 生命周期: onModuleLoaded → onPackageReady → installHooks
 * 热重载:   onHotReloading 返回 true + onHotReloaded unhook旧handle + installHooks 重装
 *
 * 注意:
 *   - 禁止调用传统 de.robv.android.xposed.* API
 *   - Class.forName 的 initialize 必须 false (触发 <clinit> 会让 APP 崩溃!)
 *   - 方法名匹配: r9.k 的 a/c/e/n/s/u 在各 Via 版本保持一致 (混淆类名会变, 方法名稳定)
 */
public class MainHook extends XposedModule {

    private static final String TAG = "ViaWB";

    /** 保存被 hook 应用的 classLoader (热重载 fallback 用) */
    private ClassLoader mAppClassLoader;

    // ========== Hooker 内部类 ==========

    /** 恒返回 Boolean.FALSE — 适用于白名单判定方法 s/a/c/e/n */
    public static class FalseHooker implements XposedInterface.Hooker {
        @Override
        public Object intercept(XposedInterface.Chain chain) {
            return Boolean.FALSE;
        }
    }

    /** 空操作 (返回 null) — 适用于配置解析器 u (void 方法) */
    public static class VoidHooker implements XposedInterface.Hooker {
        @Override
        public Object intercept(XposedInterface.Chain chain) {
            return null;
        }
    }

    // ========== 构造 ==========

    public MainHook() {
        super();
    }

    // ========== 核心 Hook 辅助方法 ==========

    /**
     * 按方法名 hook 目标类的所有同名方法, 返回成功数量
     * 等价旧 API 的 XposedBridge.hookAllMethods; 兼容不同参数签名
     */
    private int hookMethod(ClassLoader cl, String className, String methodName, XposedInterface.Hooker hooker) {
        int count = 0;
        try {
            // Class.forName(className, false, classLoader) — initialize 必须 false!
            Class<?> clazz = Class.forName(className, false, cl);
            Method[] methods = clazz.getDeclaredMethods();
            for (Method m : methods) {
                if (m.getName().equals(methodName)) {
                    hook(m).setExceptionMode(XposedInterface.ExceptionMode.PROTECTIVE)
                           .intercept(hooker);
                    count++;
                }
            }
        } catch (Throwable ignored) {
        }
        return count;
    }

    /**
     * 安装全部 hooks (onPackageReady 与 onHotReloaded 共用)
     * 返回真实 hook 成功数量 (诊断日志用)
     */
    private int installHooks(ClassLoader cl) {
        FalseHooker falseHooker = new FalseHooker();
        VoidHooker voidHooker = new VoidHooker();
        int total = 0;

        String targetClass = "r9.k"; // Via 白名单类 (混淆名)

        // s: 核心域名匹配器 → false
        total += hookMethod(cl, targetClass, "s", falseHooker);
        // a: 资源嗅探白名单 (wlr) → false
        total += hookMethod(cl, targetClass, "a", falseHooker);
        // c: 下载功能白名单 (wld) → false
        total += hookMethod(cl, targetClass, "c", falseHooker);
        // e: 脚本白名单 (wls) → false
        total += hookMethod(cl, targetClass, "e", falseHooker);
        // n: 广告豁免白名单 (wlb) → false
        total += hookMethod(cl, targetClass, "n", falseHooker);
        // u: 配置解析器 (阻止白名单数据加载) → 空操作
        total += hookMethod(cl, targetClass, "u", voidHooker);

        return total;
    }

    // ========== 生命周期方法 ==========

    @Override
    public void onModuleLoaded(XposedModuleInterface.ModuleLoadedParam param) {
        log(Log.INFO, TAG, "api102 module loaded");
    }

    @Override
    public void onPackageReady(XposedModuleInterface.PackageReadyParam param) {
        ClassLoader cl = param.getClassLoader();
        mAppClassLoader = cl;

        int count = installHooks(cl);
        if (count == 0) {
            log(Log.INFO, TAG, "Via WB: subprocess, no whitelist class (r9.k) skipped");
            return;
        }
        log(Log.INFO, TAG, "Via WB: whitelist NEUTRALIZED (r9.k " + count + " methods hooked incl config parser u)");
    }

    @Override
    public boolean onHotReloading(XposedModuleInterface.HotReloadingParam param) {
        return true;
    }

    @Override
    public void onHotReloaded(XposedModuleInterface.HotReloadedParam param) {
        ClassLoader cl = null;

        // 1. 从旧 hook handle 取 app classLoader
        List<XposedInterface.HookHandle> oldHandles = param.getOldHookHandles();
        if (!oldHandles.isEmpty()) {
            XposedInterface.HookHandle handle = oldHandles.get(0);
            Executable executable = handle.getExecutable();
            cl = executable.getDeclaringClass().getClassLoader();
        }

        // 2. unhook 全部旧 hooks
        for (XposedInterface.HookHandle handle : oldHandles) {
            handle.unhook();
        }

        // 3. fallback: 用保存的 mAppClassLoader
        if (cl == null) {
            cl = mAppClassLoader;
        }
        if (cl == null) {
            return;
        }

        // 4. 重装 hooks
        installHooks(cl);
        log(Log.INFO, TAG, "hot reloaded, hooks reinstalled");
    }
}
