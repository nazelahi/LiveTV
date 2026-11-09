# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# media_kit / libmpv
-keep class com.alexmercerind.media_kit.** { *; }
-keep class dev.dart.** { *; }
-keep class androidx.media3.** { *; }

# Hive
-keep class org.hive.** { *; }
-keepclassmembers class * implements org.hive.** { *; }

# Keep model/enum names used via reflection by plugins
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**