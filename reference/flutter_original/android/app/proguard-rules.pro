# ProGuard / R8 rules for Crystal Cascade
# ─────────────────────────────────────────────────────────────────────────────

# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Play Billing Library 8.0.0 ───────────────────────────────────────────────
# Required since August 31 2026 (Play Console enforcement).
# R8 must not strip Billing API classes — Play Store validates them at runtime.
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
-keep class com.android.vending.** { *; }
-dontwarn com.android.vending.**

# ── in_app_purchase Flutter plugin ───────────────────────────────────────────
-keep class io.flutter.plugins.inapppurchase.** { *; }
-dontwarn io.flutter.plugins.inapppurchase.**

# ── AdMob ─────────────────────────────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── Play Core (Flutter deferred components / split install) ───────────────────
# R8 flags these as missing because play:core is an optional runtime dep.
# Flutter's embedding references them but they are never called in a
# standard single-APK release build, so it is safe to suppress them.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# ── AudioPlayers ──────────────────────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── flutter_local_notifications ───────────────────────────────────────────────
# Receivers are registered in AndroidManifest; R8 must keep them.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ── connectivity_plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ── Kotlin coroutines (used by in_app_purchase_android internals) ─────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.internal.MainDispatcherFactory {
    public static final kotlinx.coroutines.internal.MainDispatcherFactory INSTANCE;
}
-dontwarn kotlinx.coroutines.**

# ── Keep all public classes and methods ───────────────────────────────────────
-keep public class * {
    public protected *;
}

# ── Remove logging in release ─────────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}
