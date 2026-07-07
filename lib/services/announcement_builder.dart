class AnnouncementBuilder {
  AnnouncementBuilder._();

  static List<String> build({
    required Map<String, dynamic> result,
    required String language,
    required String mode,
  }) {
    final objects = _dedupe(
      List<String>.from(result['detected_objects'] ?? result['objects'] ?? const []),
    );
    final groups = _classify(result, objects);
    final safetyMode = mode == 'safety';

    final messages = <String>[];
    if (groups.danger.isNotEmpty) {
      messages.add(_buildDanger(language, groups.danger));
    }
    if (groups.obstacle != null) messages.add(_buildObstacle(language, groups.obstacle!));
    if (groups.persons.isNotEmpty) {
      messages.add(_buildPersons(language, groups.persons));
    }

    final normalMessage = _buildNormal(language, groups.normal);
    if (!safetyMode) {
      if (normalMessage.isNotEmpty) messages.add(normalMessage);
      return _compact(messages);
    }

    if (messages.isEmpty && normalMessage.isNotEmpty) {
      return _compact([
        language == 'ar'
            ? 'لا يوجد أي خطر قريب منك.'
            : 'No nearby danger detected.',
        normalMessage,
      ]);
    }

    return _compact(messages);
  }

  static _Classified _classify(Map<String, dynamic> result, List<String> objects) {
    final dangerLabels = {'knife', 'scissors', 'glass', 'fire', 'blade', 'gun'};
    final danger = <_ObjectItem>[];
    final normal = <_ObjectItem>[];

    final location = (result['location'] ?? result['position'] ?? 'front').toString().toLowerCase();
    final distance = _distanceCm(result);

    for (final raw in objects) {
      final item = _ObjectItem(
        label: raw,
        distanceCm: _objectDistance(result, raw, defaultValue: distance),
        location: _normalizeLocation(location, raw),
      );
      if (raw == 'person') {
        continue;
      }
      if (dangerLabels.contains(raw)) {
        danger.add(item);
      } else {
        normal.add(item);
      }
    }

    final persons = _personItems(result);
    final obstacle = _buildObstacleItem(result);

    danger.sort((a, b) => a.distanceCm.compareTo(b.distanceCm));
    normal.sort((a, b) => a.distanceCm.compareTo(b.distanceCm));
    persons.sort((a, b) => a.distanceCm.compareTo(b.distanceCm));

    return _Classified(
      danger: danger,
      obstacle: obstacle,
      persons: persons,
      normal: normal,
    );
  }

  static _ObjectItem? _buildObstacleItem(Map<String, dynamic> result) {
    final severity = (result['midas_severity'] ?? '').toString().toLowerCase().trim();
    final distance = _distanceCm(result);
    if (severity.isEmpty || distance == null) return null;
    return _ObjectItem(
      label: severity,
      distanceCm: distance,
      location: 'front',
    );
  }

  static List<_ObjectItem> _personItems(Map<String, dynamic> result) {
    final count = (result['person_count'] ?? result['people_count'] ?? 0) as int? ?? 0;
    final detected = (result['person_detected'] ?? result['personDetected']) == true;
    if (!detected) return const [];
    final bestMatch = (result['best_match'] ?? result['bestMatch'] ?? 'unknown').toString().trim();
    final scoreValue = result['best_score'] ?? result['bestScore'];
    final bestScore = scoreValue is num ? scoreValue.toDouble() : 0.0;
    final recognized = bestMatch.isNotEmpty && bestMatch.toLowerCase() != 'unknown' && bestScore >= 0.5;
    final personCount = count <= 0 ? 1 : count;
    return List.generate(personCount, (index) {
      return _ObjectItem(
        label: recognized && index == 0 ? bestMatch.toLowerCase() : 'person',
        distanceCm: _distanceCm(result) ?? 9999,
        location: _normalizeLocation((result['location'] ?? result['position'] ?? 'front').toString().toLowerCase(), 'person'),
        recognizedName: recognized && index == 0 ? bestMatch : null,
      );
    });
  }

  static String _buildDanger(String language, List<_ObjectItem> items) {
    final labels = _uniqueByProximity(items).map((e) => _label(language, e.label)).toList();
    final first = labels.first;
    final rest = labels.skip(1).toList();
    if (language == 'ar') {
      return rest.isEmpty
          ? 'تحذير، توجد $first أمامك.'
          : 'تحذير، توجد $first وأيضًا ${_joinArabic(rest)} أمامك.';
    }
    return rest.isEmpty
        ? 'Warning. A ${first.toLowerCase()} is in front of you.'
        : 'Warning. A ${first.toLowerCase()} and ${_joinEnglish(rest)} are in front of you.';
  }

  static String _buildObstacle(String language, _ObjectItem item) {
    final dist = _distanceText(language, item.distanceCm);
    if (language == 'ar') {
      return 'انتبه، يوجد عائق أمامك على بعد $dist.';
    }
    return 'Caution. An obstacle is approximately $dist ahead of you.';
  }

  static String _buildPersons(String language, List<_ObjectItem> items) {
    final unique = _uniqueByProximity(items);
    final recognized = unique.where((e) => e.recognizedName != null).toList();
    final unknown = unique.where((e) => e.recognizedName == null).toList();
    if (unique.length == 1) {
      final one = unique.first;
      if (one.recognizedName != null) {
        return language == 'ar'
            ? 'يوجد ${one.recognizedName} أمامك.'
            : '${one.recognizedName} is in front of you.';
      }
      return language == 'ar' ? 'يوجد شخص أمامك.' : 'A person is in front of you.';
    }
    if (recognized.isNotEmpty) {
      final name = recognized.first.recognizedName!;
      final others = unique.length - 1;
      return language == 'ar'
          ? 'يوجد $name أمامك${others > 0 ? ' ومعه ${_arabicPersonCount(others)} آخر${others > 1 ? 'ون' : ''}' : ''}.'
          : '$name is in front of you${others > 0 ? ' with ${_englishPersonCount(others)} other${others > 1 ? 's' : ''}' : ''}.';
    }
    return language == 'ar'
        ? 'يوجد ${_arabicPersonCount(unknown.length)} أمامك.'
        : 'There are ${_englishPersonCount(unknown.length)} people in front of you.';
  }

  static String _buildNormal(String language, List<_ObjectItem> items) {
    final unique = _uniqueByLocationAndLabel(items);
    if (unique.isEmpty) return '';
    final grouped = <String, List<_ObjectItem>>{};
    for (final item in unique) {
      grouped.putIfAbsent(item.location, () => []).add(item);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) => _locationRank(a).compareTo(_locationRank(b)));

    final parts = <String>[];
    for (final key in keys) {
      final values = grouped[key]!..sort((a, b) => a.distanceCm.compareTo(b.distanceCm));
      final labels = values.map((e) => _label(language, e.label)).toList();
      final joined = language == 'ar' ? _joinArabic(labels) : _joinEnglish(labels);
      parts.add(language == 'ar' ? '$joined ${_locationAr(key)}' : '$joined ${_locationEn(key)}');
    }

    return language == 'ar'
        ? 'يوجد ${_joinArabic(parts)}.'
        : 'You can see ${_joinEnglish(parts)}.';
  }

  static List<String> _dedupe(List<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final n = item.toLowerCase().trim();
      if (n.isEmpty) continue;
      if (seen.add(n)) out.add(n);
    }
    return out;
  }

  static List<_ObjectItem> _uniqueByProximity(List<_ObjectItem> items) {
    final map = <String, _ObjectItem>{};
    for (final item in items) {
      final key = '${item.label}|${item.location}';
      final existing = map[key];
      if (existing == null || item.distanceCm < existing.distanceCm) {
        map[key] = item;
      }
    }
    final out = map.values.toList()
      ..sort((a, b) => a.distanceCm.compareTo(b.distanceCm));
    return out;
  }

  static List<_ObjectItem> _uniqueByLocationAndLabel(List<_ObjectItem> items) {
    final map = <String, _ObjectItem>{};
    for (final item in items) {
      final key = '${item.label}|${item.location}';
      final existing = map[key];
      if (existing == null || item.distanceCm < existing.distanceCm) {
        map[key] = item;
      }
    }
    final out = map.values.toList()
      ..sort((a, b) => a.distanceCm.compareTo(b.distanceCm));
    return out;
  }

  static int _locationRank(String location) {
    switch (location) {
      case 'front':
        return 0;
      case 'left':
        return 1;
      case 'right':
        return 2;
      case 'behind':
        return 3;
      default:
        return 4;
    }
  }

  static String _normalizeLocation(String location, String label) {
    final normalized = location.toLowerCase();
    if (normalized.contains('left')) return 'left';
    if (normalized.contains('right')) return 'right';
    if (normalized.contains('behind') || normalized.contains('back')) return 'behind';
    if (normalized.contains('front') || normalized.contains('center') || normalized.contains('centered')) return 'front';
    if (label == 'table' || label == 'door') return 'front';
    return 'front';
  }

  static double? _distanceCm(Map<String, dynamic> result) {
    final value = result['midas_distance_cm'];
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static double _objectDistance(Map<String, dynamic> result, String label, {required double? defaultValue}) {
    final key = '${label}_distance_cm';
    final value = result[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('$value');
    return parsed ?? defaultValue ?? 9999;
  }

  static String _distanceText(String language, double distance) {
    final rounded = distance.round();
    return language == 'ar' ? '$rounded سنتيمتر' : '$rounded centimeters';
  }

  static String _label(String language, String label) {
    if (language != 'ar') return label;
    switch (label) {
      case 'chair':
        return 'كرسي';
      case 'table':
      case 'dining table':
        return 'طاولة';
      case 'door':
        return 'باب';
      case 'bottle':
        return 'زجاجة';
      case 'cup':
        return 'كوب';
      case 'book':
        return 'كتاب';
      case 'knife':
        return 'سكين';
      case 'scissors':
        return 'مقص';
      case 'person':
        return 'شخص';
      case 'bed':
        return 'سرير';
      case 'sofa':
      case 'couch':
        return 'أريكة';
      case 'tv':
      case 'monitor':
        return 'شاشة';
      case 'laptop':
        return 'لابتوب';
      case 'mouse':
        return 'ماوس';
      case 'keyboard':
        return 'كيبورد';
      case 'cell phone':
      case 'mobile phone':
      case 'phone':
        return 'هاتف';
      case 'backpack':
        return 'حقيبة';
      case 'umbrella':
        return 'مظلة';
      case 'shoe':
        return 'حذاء';
      case 'car':
        return 'سيارة';
      case 'bicycle':
        return 'دراجة';
      case 'motorcycle':
        return 'دراجة نارية';
      case 'bus':
        return 'حافلة';
      case 'truck':
        return 'شاحنة';
      case 'cat':
        return 'قطة';
      case 'dog':
        return 'كلب';
      case 'bird':
        return 'طائر';
      default:
        return label;
    }
  }

  static String _locationAr(String location) {
    switch (location) {
      case 'left':
        return 'على يسارك';
      case 'right':
        return 'على يمينك';
      case 'behind':
        return 'خلفك';
      default:
        return 'أمامك';
    }
  }

  static String _locationEn(String location) {
    switch (location) {
      case 'left':
        return 'on your left';
      case 'right':
        return 'on your right';
      case 'behind':
        return 'behind you';
      default:
        return 'in front of you';
    }
  }

  static String _joinArabic(List<String> parts) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return '${parts.first} و${parts.last}';
    return '${parts.sublist(0, parts.length - 1).join('، ')}، و${parts.last}';
  }

  static String _joinEnglish(List<String> parts) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return '${parts.first} and ${parts.last}';
    return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
  }

  static String _englishPersonCount(int count) {
    switch (count) {
      case 1:
        return 'one person';
      case 2:
        return 'two people';
      case 3:
        return 'three people';
      default:
        return '$count people';
    }
  }

  static String _arabicPersonCount(int count) {
    switch (count) {
      case 1:
        return 'شخص';
      case 2:
        return 'شخصان';
      case 3:
        return 'ثلاثة أشخاص';
      default:
        return '$count أشخاص';
    }
  }

  static List<String> _compact(List<String> messages) =>
      messages.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

class _Classified {
  final List<_ObjectItem> danger;
  final _ObjectItem? obstacle;
  final List<_ObjectItem> persons;
  final List<_ObjectItem> normal;
  const _Classified({
    required this.danger,
    required this.obstacle,
    required this.persons,
    required this.normal,
  });
}

class _ObjectItem {
  final String label;
  final double distanceCm;
  final String location;
  final String? recognizedName;

  const _ObjectItem({
    required this.label,
    required this.distanceCm,
    required this.location,
    this.recognizedName,
  });
}
