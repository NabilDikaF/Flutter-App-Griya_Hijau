# Flutter embedding & plugin channels
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage & Android Keystore / Tink crypto classes
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# supabase_flutter Android deep-link bridge (app_links)
-keep class com.llfbandit.app_links.** { *; }
-dontwarn com.llfbandit.app_links.**

# Keep enum reflection for platform channel serialization
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Flutter merujuk kelas Play Core (deferred components) yang tidak dipakai aplikasi ini.
-dontwarn com.google.android.play.core.**
