# ProGuard rules for Crystal Cascade

# ── AdMob ─────────────────────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── Flutter ───────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Play Core (Flutter deferred components / split install) ───────────
# R8 flags these as missing because play:core is an optional runtime dep.
# Flutter's embedding references them but they are never called in a
# standard single-APK release build, so it is safe to suppress them.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# ── Keep public classes and methods ───────────────────────────────────
-keep public class * {
    public protected *;
}

# ── AudioPlayers ──────────────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }

# ── Shared Preferences ────────────────────────────────────────────────
-keep class android.content.SharedPreferences { *; }

# ── Remove logging in release ─────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}
