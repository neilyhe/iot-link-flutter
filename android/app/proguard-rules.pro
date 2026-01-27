# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter 生成的插件注册类
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# 保护所有 native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保护所有包含 native 方法的类
-keepclasseswithmembers class * {
    native <methods>;
}

# 保护枚举类
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保护 Parcelable 实现类
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# 保护 Serializable 类
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

-keep class com.tencent.**{ *; }

# XP2P SDK
-keep class com.tencent.xp2p_sdk.** { *; }
-keep class com.tencent.xnet.** { *; }
-keep interface com.tencent.xnet.** { *; }
-dontwarn com.tencent.xnet.**

# SuperPlayer SDK
-keep class com.tencent.vod.** { *; }
-keep class com.tencent.liteav.** { *; }
-keep class com.tencent.rtmp.** { *; }
-keep class com.tencent.ugc.** { *; }
-dontwarn com.tencent.liteav.**
-dontwarn com.tencent.rtmp.**

# 腾讯云 SDK
-keep class com.tencent.** { *; }
-dontwarn com.tencent.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# 保护反射
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# 保护泛型
-keepattributes Signature

# 保护异常
-keepattributes Exceptions

# 保护行号信息（用于调试崩溃堆栈）
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# WebView
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String);
}

# JavaScript Interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Play Core（可选功能，忽略警告）
-dontwarn com.google.android.play.core.**

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# 保护自定义 View
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# 保护 R 文件
-keepclassmembers class **.R$* {
    public static <fields>;
}

# 移除日志（可选，生产环境建议启用）
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
# }
