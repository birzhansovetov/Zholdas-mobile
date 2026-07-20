-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations, AnnotationDefault
-keep interface com.example.zholdas.data.remote.** { *; }
-keep,includedescriptorclasses class com.example.zholdas.data.model.**$$serializer { *; }
-keepclassmembers class com.example.zholdas.data.model.** { *** Companion; }

# Do not retain exception messages, identifiers, or other diagnostic data in release logs.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}
