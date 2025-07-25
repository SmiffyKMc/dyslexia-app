# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Gemma / MediaPipe AI inference
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class mediapipe.** { *; }

# Keep all native methods and their classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all JNI methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Google Protobuf - keep all proto classes
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class * extends com.google.protobuf.GeneratedMessage { *; }
-keep class com.google.protobuf.** { *; }

# MediaPipe specific keeps
-keep class com.google.mediapipe.proto.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-keep class com.google.mediapipe.tasks.** { *; }

# SSL/TLS library keeps (for networking)
-keep class org.bouncycastle.** { *; }
-keep class org.conscrypt.** { *; }
-keep class org.openjsse.** { *; }

# Annotation processing keeps
-keep class javax.lang.model.** { *; }
-keep class javax.annotation.processing.** { *; }

# Auto-value annotation processor
-keep class com.google.auto.value.** { *; }
-keep class autovalue.shaded.** { *; }

# OkHttp networking
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep all enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keep class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Prevent obfuscation of classes with reflection
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# TensorFlow Lite (if used by flutter_gemma)
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.** { *; }

# Keep Flutter plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Speech recognition and TTS
-keep class android.speech.** { *; }
-keep class android.media.** { *; }

# Camera and image processing
-keep class androidx.camera.** { *; }
-keep class android.graphics.** { *; }

# Flutter specific
-dontwarn io.flutter.embedding.**
-dontwarn androidx.**
-dontwarn com.google.android.material.**

# Suppress warnings for optional dependencies
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.lang.model.**
-dontwarn javax.annotation.processing.**

# R8 generated missing rules (optional dependencies)
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
-dontwarn com.google.protobuf.Internal$ProtoMethodMayReturnNull
-dontwarn com.google.protobuf.Internal$ProtoNonnullApi
-dontwarn com.google.protobuf.ProtoField
-dontwarn com.google.protobuf.ProtoPresenceBits
-dontwarn com.google.protobuf.ProtoPresenceCheckedField
-dontwarn javax.tools.Diagnostic$Kind
-dontwarn javax.tools.JavaFileObject$Kind
-dontwarn javax.tools.JavaFileObject
-dontwarn javax.tools.SimpleJavaFileObject

# Additional javax.tools classes (annotation processing tools)
-dontwarn javax.tools.** 