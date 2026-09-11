# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_webrtc JNI / reflection models (do not strip)
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn com.cloudwebrtc.webrtc.**

# Keep native method names used via JNI
-keepclasseswithmembernames class * {
    native <methods>;
}
