/// API keys injected at build time via --dart-define.
/// Users never see or manage these directly.
class BundledKeys {
  BundledKeys._();

  static const geminiKey = String.fromEnvironment('GEMINI_KEY');
  static const voyageKey = String.fromEnvironment('VOYAGE_KEY');

  static bool get hasGemini => geminiKey.isNotEmpty;
  static bool get hasVoyage => voyageKey.isNotEmpty;
}
