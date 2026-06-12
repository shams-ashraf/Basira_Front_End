import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_header.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({Key? key}) : super(key: key);

  @override
  _ChildProfileScreenState createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  bool edit = false;
  String name = "Ahmed Ali";
  String age = "5";
  String school = "NIS School";
  String? authId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    authId = prefs.getString('linked_child_id') ??
        prefs.getString('child_id') ??
        prefs.getString('auth_id') ??
        'default';
    setState(() {
      name = prefs.getString('child_profile_${authId}_name') ?? "Ahmed Ali";
      age = prefs.getString('child_profile_${authId}_age') ?? "5";
      school = prefs.getString('child_profile_${authId}_school') ?? "NIS School";
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (authId != null) {
      await prefs.setString('child_profile_${authId}_name', name);
      await prefs.setString('child_profile_${authId}_age', age);
      await prefs.setString('child_profile_${authId}_school', school);
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_id');
    await prefs.remove('linked_child_id');
    await prefs.remove('child_id');
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildUnknownImage(String path, String source) {
    if (source == 'backend') {
      // Append a timestamp to bust cache and ensure fresh image
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final url = path.contains('?') ? "$path&cb=$cacheBuster" : "$path?cb=$cacheBuster";
      return Image.network(
        url,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 220,
          child: Center(
              child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: "Child Profile 👶"),
      backgroundColor: const Color(0xFFEEF4FB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFF80DEEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            circle("👶"),
            field("Name", name, (val) => name = val),
            field("Age", age, (val) => age = val),
            field("School", school, (val) => school = val),
            ElevatedButton(
              onPressed: () async {
                if (edit) await _saveProfile();
                setState(() => edit = !edit);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: edit ? Colors.green : const Color(0xFF5B8DEF),
                elevation: 4,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(edit ? "💾 SAVE CHANGES" : "✏️ EDIT PROFILE"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/ai-lab'),
              icon: const Icon(Icons.science),
              label: const Text('AI Lab'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8DEF),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget circle(String icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(child: Text(icon, style: const TextStyle(fontSize: 50))),
    );
  }

  Widget field(String label, String value, Function(String) onChange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        enabled: edit,
        controller: TextEditingController(text: value),
        onChanged: onChange,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
