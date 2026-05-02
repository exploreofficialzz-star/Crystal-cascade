# ProGuard rules for Crystal Cascade
# AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep public classes and methods
-keep public class * {
    public protected *;
}

# AudioPlayers
-keep class xyz.luan.audioplayers.** { *; }

# Shared Preferences
-keep class android.content.SharedPreferences { *; }

# Remove logging
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}