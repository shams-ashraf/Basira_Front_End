import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:voice_test/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backend_service.dart';
import '../../l10n.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});
  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> with WidgetsBindingObserver {
  String? linkedChildId;
  String? linkedChildName;
  List<Map<String, dynamic>> _recentAlerts = [];
  bool _loadingAlerts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLinkedChild();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLinkedChild();
    }
  }

  Future<void> _loadLinkedChild() async {
    final prefs = await SharedPreferences.getInstance();

    // Sync language from parent to child on every load
    final parentLang = prefs.getString('language') ?? 'en';
    L10n.setLanguage(parentLang);

    setState(() {
      linkedChildId = prefs.getString('linked_child_id');
      if (linkedChildId != null) {
        final liveName = prefs.getString('child_profile_${linkedChildId}_name');
        linkedChildName = liveName ?? prefs.getString('linked_child_name');
      } else {
        linkedChildName = null;
      }
    });
    await _loadRecentAlerts();
  }

  Future<void> _loadRecentAlerts() async {
    if (linkedChildId == null) {
      if (mounted) {
        setState(() => _recentAlerts = []);
      }
      return;
    }
    setState(() => _loadingAlerts = true);
    final alerts = await BackendService.instance.getAlerts(childId: linkedChildId);
    if (!mounted) return;
    setState(() {
      _recentAlerts = alerts.take(3).toList();
      _loadingAlerts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEEF4FB),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 40),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.tr('parent_welcome'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(L10n.tr('parent_monitor'), style: TextStyle(color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner, size: 28),
                      tooltip: L10n.isArabic ? 'مسح QR الطفل' : 'Scan child QR',
                      onPressed: () => _openScannerSheet(),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, size: 28),
                      onPressed: () => Navigator.pushNamed(context, "/settings").then((_) {
                        _loadLinkedChild();
                        setState(() {});
                      }),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, size: 28),
                      tooltip: L10n.tr('profile_signout'),
                      onPressed: () async {
                        await AuthService.instance.logout();
                        await Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 20),

            // Linked Child Section
            if (linkedChildId == null)
              card(
                color: Colors.blue.shade50,
                child: Text(
                  L10n.isArabic
                      ? 'يرجى ربط طفلك عن طريق مسح رمز QR.'
                      : 'Please link your child by scanning the QR Code.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (linkedChildId != null)
              card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.tr('parent_linked_child'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
                          child: Center(child: Text("👦", style: TextStyle(fontSize: 24))),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(linkedChildName ?? L10n.tr('parent_unknown_child'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("ID: $linkedChildId", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                          child: Text(L10n.tr('parent_connected'), style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Status Card
            card(
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(L10n.tr('parent_child_safe'), style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(L10n.tr('parent_last_updated')),
                    ],
                  ),
                ],
              ),
            ),

            // Safe Card
            card(
              color: Colors.green.shade100,
              child: Row(children: [Text("🟢"), SizedBox(width: 10), Text(L10n.tr('parent_no_danger'), style: TextStyle(fontWeight: FontWeight.bold))]),
            ),

            if (linkedChildId != null)
              card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(L10n.tr('parent_recent_alerts'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadingAlerts ? null : _loadRecentAlerts,
                        ),
                      ],
                    ),
                    if (_loadingAlerts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_recentAlerts.isEmpty)
                      Text(L10n.tr('parent_no_alerts')),
                    ..._recentAlerts.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${alert['type'] ?? 'Alert'}: ${alert['message'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Grid Actions
            grid(context),
          ],
        ),
      ),
    );
  }

  Widget card({Widget? child, Color? color}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget grid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: [
        item("📱", L10n.tr('parent_link_device'), () => _openScannerSheet()),
        item("🤖", L10n.tr('parent_camera_ai'), () => Navigator.pushNamed(context, "/camera-ai").then((_) => _loadLinkedChild())),
        item("🚨", L10n.tr('parent_alerts'), () => Navigator.pushNamed(context, "/alerts").then((_) => _loadLinkedChild())),
        item("📸", L10n.tr('parent_unknown'), () => Navigator.pushNamed(context, "/unknown").then((_) => _loadLinkedChild())),
        item("👥", L10n.tr('parent_persons'), () => Navigator.pushNamed(context, "/persons").then((_) => _loadLinkedChild())),
      ],
    );
  }

  Widget item(String icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.all(6),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: 26)),
            SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _openScannerSheet() async {
    bool isScanned = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) async {
                  if (isScanned) return;
                  for (final barcode in capture.barcodes) {
                    final rawValue = barcode.rawValue;
                    if (rawValue == null || rawValue.isEmpty) continue;
                    try {
                      final data = jsonDecode(rawValue);
                      if (data['type'] != 'child_link') continue;
                      isScanned = true;
                      await AuthService.instance.linkChild(data['id'].toString());
                      final childName = data['childName'] ?? 'Child';
                      await BackendService.instance.linkChild(data['id'].toString(), childName);
                      final prefs = await SharedPreferences.getInstance();
                      if (data['childName'] != null) {
                        await prefs.setString('linked_child_name', data['childName']);
                      }
                      if (!mounted) return;
                      Navigator.pop(sheetContext);
                      await _loadLinkedChild();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            L10n.isArabic
                                ? 'تم ربط الطفل بنجاح!'
                                : 'Child linked successfully!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      return;
                    } catch (_) {
                      continue;
                    }
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Positioned(
                bottom: 60,
                left: 24,
                right: 24,
                child: Text(
                  L10n.isArabic
                      ? 'وجّه رمز QR الخاص بالطفل إلى المنتصف'
                      : "Center the child's QR code in the frame",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
