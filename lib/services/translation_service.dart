import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class LocalTranslationService {
  LocalTranslationService._();
  static final LocalTranslationService instance = LocalTranslationService._();

  OnDeviceTranslator? _translator;
  bool _isDownloading = false;

  Future<void> init() async {
    if (_translator != null) return;
    
    final modelManager = OnDeviceTranslatorModelManager();
    
    // Check if Arabic is downloaded
    final isDownloaded = await modelManager.isModelDownloaded(TranslateLanguage.arabic.bcpCode);
    if (!isDownloaded) {
      debugPrint('[Translation] Arabic model not found. Downloading...');
      _isDownloading = true;
      final downloaded = await modelManager.downloadModel(TranslateLanguage.arabic.bcpCode);
      _isDownloading = false;
      if (!downloaded) {
        debugPrint('[Translation] Failed to download Arabic model');
        return;
      }
      debugPrint('[Translation] Arabic model downloaded successfully!');
    }

    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.arabic,
    );
    debugPrint('[Translation] Translator initialized.');
  }

  bool get isReady => _translator != null;
  bool get isDownloading => _isDownloading;

  Future<String> translate(String englishText) async {
    if (englishText.trim().isEmpty) return '';
    
    if (_translator == null) {
      await init();
      if (_translator == null) return englishText; // Fallback to english if it still fails
    }

    try {
      final arabicText = await _translator!.translateText(englishText);
      return _normalizeArabicSafetyTerms(arabicText);
    } catch (e) {
      debugPrint('[Translation] Error during translation: $e');
      return englishText;
    }
  }

  String _normalizeArabicSafetyTerms(String text) {
    var normalized = text;

    // Keep safety-related Arabic wording consistent and avoid transliterated "obstacle".
    normalized = normalized.replaceAll(RegExp(r'(?i)\bobstacle\b'), 'عائق');
    normalized = normalized.replaceAll('أوبستاكل', 'عائق');
    normalized = normalized.replaceAll('اوبستاكل', 'عائق');
    normalized = normalized.replaceAll('أوبسيتيكال', 'عائق');
    normalized = normalized.replaceAll('اوبسيتيكال', 'عائق');
    normalized = normalized.replaceAll('أوبيستكل', 'عائق');
    normalized = normalized.replaceAll('اوبيستكل', 'عائق');
    normalized = normalized.replaceAll('أوبستكل', 'عائق');
    normalized = normalized.replaceAll('اوبستكل', 'عائق');

    return normalized;
  }

  void dispose() {
    _translator?.close();
    _translator = null;
  }
}
