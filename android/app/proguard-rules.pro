# --- TensorFlow Lite required keep rules ---
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep TFLite GPU delegate and related options
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Optional: prevent stripping Flutter plugin registrant
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**
