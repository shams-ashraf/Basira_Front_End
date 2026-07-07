import '../l10n.dart';

class LocalizedSpeechText {
  static const Map<String, String> _objectLabelsAr = {
    'person': 'شخص',
    'man': 'رجل',
    'woman': 'امرأة',
    'boy': 'ولد',
    'girl': 'بنت',
    'child': 'طفل',
    'car': 'سيارة',
    'bus': 'أتوبيس',
    'truck': 'شاحنة',
    'bicycle': 'دراجة',
    'motorcycle': 'دراجة نارية',
    'chair': 'كرسي',
    'table': 'طاولة',
    'bed': 'سرير',
    'cup': 'كوب',
    'bottle': 'زجاجة',
    'book': 'كتاب',
    'phone': 'هاتف',
    'cell phone': 'هاتف',
    'laptop': 'لابتوب',
    'tv': 'تلفاز',
    'television': 'تلفاز',
    'remote': 'ريموت',
    'keyboard': 'لوحة مفاتيح',
    'mouse': 'فأرة',
    'backpack': 'حقيبة',
    'bag': 'حقيبة',
    'handbag': 'حقيبة يد',
    'umbrella': 'مظلة',
    'knife': 'سكين',
    'fork': 'شوكة',
    'spoon': 'ملعقة',
    'bowl': 'وعاء',
    'plate': 'طبق',
    'window': 'شباك',
    'door': 'باب',
    'wall': 'حائط',
    'street': 'شارع',
    'road': 'طريق',
    'tree': 'شجرة',
    'flower': 'زهرة',
    'cupcake': 'كب كيك',
    'cake': 'كيك',
    'dog': 'كلب',
    'cat': 'قطة',
    'bird': 'طائر',
    'bike': 'دراجة',
  };

  static const Map<String, String> _phraseReplacementsAr = {
    'a person': 'شخص',
    'an object': 'شيء',
    'the image shows': 'تظهر الصورة',
    'this image shows': 'تظهر هذه الصورة',
    'image shows': 'تُظهر الصورة',
    'a man': 'رجل',
    'a woman': 'امرأة',
    'a boy': 'ولد',
    'a girl': 'بنت',
    'standing': 'واقف',
    'sitting': 'جالس',
    'walking': 'يمشي',
    'riding': 'يركب',
    'holding': 'يمسك',
    'near': 'قريب',
    'far': 'بعيد',
    'left': 'اليسار',
    'right': 'اليمين',
    'front': 'الأمام',
    'behind': 'الخلف',
    'on the left': 'على اليسار',
    'on the right': 'على اليمين',
    'in front of you': 'أمامك',
    'ahead': 'أمامك',
    'close': 'قريب',
    'careful': 'انتبه',
    'watch out': 'انتبه',
    'there is': 'يوجد',
    'appears': 'ويبدو أنه',
    'looks like': 'ويبدو أنه',
    'detected': 'تم رصد',
    'scene': 'مشهد',
  };

  static String objectLabel(String label, {String language = 'en'}) {
    final text = label.trim();
    if (language != 'ar' || text.isEmpty) return text;
    return _objectLabelsAr[text.toLowerCase()] ?? text;
  }

  static String sceneCaption(String text, {String language = 'en'}) {
    final caption = text.trim();
    if (language != 'ar' || caption.isEmpty) return caption;

    var translated = caption;
    final lower = caption.toLowerCase();

    for (final entry in _phraseReplacementsAr.entries) {
      translated = translated.replaceAll(entry.key, entry.value);
      translated = translated.replaceAll(entry.key.toUpperCase(), entry.value);
    }

    for (final entry in _objectLabelsAr.entries) {
      translated = translated.replaceAll(' ${entry.key} ', ' ${entry.value} ');
      translated = translated.replaceAll(entry.key, entry.value);
    }

    translated = translated.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (translated == lower || translated.isEmpty) {
      return 'المشهد يظهر: $caption';
    }

    if (!translated.endsWith('.') && !translated.endsWith('!') && !translated.endsWith('؟')) {
      translated = '$translated.';
    }

    return translated;
  }

  static String sceneSentence({
    required String english,
    String language = 'en',
    String prefixAr = 'المشهد يظهر',
    String prefixEn = 'The scene shows',
  }) {
    final base = english.trim();
    if (language != 'ar') return base;
    final translated = sceneCaption(base, language: 'ar');
    if (translated.isEmpty) return translated;
    if (translated.startsWith('المشهد يظهر')) return translated;
    return '$prefixAr: $translated';
  }

  static String objectSentence({
    required String objectLabelText,
    required String position,
    required String distance,
    String language = 'en',
  }) {
    if (language != 'ar') {
      return '$objectLabelText on your $position and it looks $distance.';
    }
    final label = objectLabel(objectLabelText, language: 'ar');
    final pos = position.trim().isEmpty ? 'أمامك' : position.trim();
    final dist = distance.trim().isEmpty ? 'قريبة' : distance.trim();
    return 'أرى $label على $pos ويبدو أنه $dist.';
  }

  static String personSentence({
    required String position,
    required String distance,
    bool hasScore = false,
    String label = 'person',
    String language = 'en',
  }) {
    if (language != 'ar') {
      if (hasScore) {
        return '$label is on your $position and appears $distance.';
      }
      return 'I can see a person on your $position.';
    }
    final pos = position.trim().isEmpty ? 'أمامك' : position.trim();
    final dist = distance.trim().isEmpty ? 'قريب' : distance.trim();
    return hasScore
        ? 'أرى $label على $pos ويبدو أنه $dist.'
        : 'أرى شخصًا على $pos.';
  }
}
