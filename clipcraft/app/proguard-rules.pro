# Anthropic SDK (Kotlin + Jackson) uses reflection for JSON.
-keep class com.anthropic.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**

# Vosk talks to its native library through JNA.
-keep class com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**

# OkHttp / Okio optional platform classes.
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.slf4j.**

# Referenced only by code paths ClipCraft doesn't use on Android:
# the SDK's class-to-JSON-schema helper (we pass a hand-written schema) and
# OpenTelemetry's compile-time AutoValue annotation.
-dontwarn java.lang.reflect.AnnotatedType
-dontwarn java.lang.reflect.AnnotatedParameterizedType
-dontwarn com.google.auto.value.AutoValue
-dontwarn com.google.auto.value.**
