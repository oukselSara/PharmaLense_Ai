# Add project specific ProGuard rules here.

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Google Play Services Vision
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.android.gms.vision.**

# Keep ML Kit Text Recognition classes (all languages)
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep Google Play Services classes
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Google Play Core classes
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep camera related classes
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent obfuscation of generic signatures
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
