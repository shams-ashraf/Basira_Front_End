import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_header.dart';
import '../../l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String language = 'en';
  bool _langSaved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language') ?? prefs.getString('voice_language') ?? 'en';
    setState(() {
      language = savedLanguage.startsWith('ar') ? 'ar' : 'en';
    });
  }

  void _setLanguage(String value) {
    setState(() => language = value);
  }

  Future<void> _saveLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setString('voice_language', language == 'ar' ? 'ar-EG' : 'en-US');

    final linkedChildId = prefs.getString('linked_child_id');
    if (linkedChildId != null && linkedChildId.isNotEmpty) {
      await prefs.setString('child_language_$linkedChildId', language);
      await prefs.setString('child_voice_language_$linkedChildId', language == 'ar' ? 'ar-EG' : 'en-US');
    }

    L10n.setLanguage(language);
    setState(() => _langSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _langSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: L10n.tr('settings_title')),
      backgroundColor: const Color(0xFFEEF4FB),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.isArabic ? L10n.tr('settings_language') : 'Language',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E6B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioListTile<String>(
                    value: 'en',
                    groupValue: language,
                    title: const Text('English'),
                    onChanged: (value) {
                      if (value != null) _setLanguage(value);
                    },
                  ),
                  RadioListTile<String>(
                    value: 'ar',
                    groupValue: language,
                    title: Text(L10n.isArabic ? 'العربية' : 'Arabic'),
                    subtitle: Text(L10n.isArabic ? 'صوت ونص عربي' : 'Arabic voice and UI'),
                    onChanged: (value) {
                      if (value != null) _setLanguage(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveLanguage,
                      icon: const Icon(Icons.save),
                      label: Text(L10n.isArabic ? L10n.tr('settings_save_lang') : 'Save Language'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_langSaved)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        L10n.tr('settings_lang_saved'),
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget card(Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}
