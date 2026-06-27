# Flutter Mobile Scanner / ML Kit rules to prevent R8 from stripping classes needed for barcode scanning
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.android.odml.image.** { *; }
