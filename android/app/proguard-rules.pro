# =========================================================
# Glimpse — ProGuard / R8 keep rules
# =========================================================

# ── Flutter engine ────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── RevenueCat (purchases_flutter) ────────────────────────
-keep class com.revenuecat.purchases.** { *; }
-keep class com.revenuecat.purchases_ui_flutter.** { *; }
-keepattributes InnerClasses
-keepattributes Signature

# ── Isar database ─────────────────────────────────────────
# Isar uses code generation; keep all generated IsarObject subclasses.
-keep class **.isar_generated.** { *; }
-keep class **_isar.** { *; }
-keep class **Isar { *; }
-keep class **IsarCollection { *; }
# Isar runtime reflection
-keepclassmembers class * {
    @isar.IsarProperty <fields>;
    @isar.IsarId <fields>;
}
-keep class isar.** { *; }
-keep class com.isar.** { *; }

# ── Google Generative AI (Gemini) ───────────────────────
-keep class com.google.ai.** { *; }

# ── Android notifications ────────────────────────────────
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }
-keep class androidx.work.** { *; }

# ── URL metadata / link preview ──────────────────────────
# AnyLinkPreview uses reflection on HTML meta tags — no specific
# keep rules needed; it uses standard HTTP and HTML parsing.

# ── Path provider / shared preferences ────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── Serialization models used via JSON ────────────────────
# Keep all model classes that are serialized/deserialized.
# These are in the Dart layer so R8 cannot strip them, but
# any platform channels accessing them need protection.
-keep class com.shinrinyoku.glimpse.** { *; }

# ── General ──────────────────────────────────────────────
# Don't warn about packages we don't use but are pulled transitively
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn retrofit2.**
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Play Core (deferred components — not used but referenced by Flutter) ──
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task