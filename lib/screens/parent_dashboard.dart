import 'package:flutter/material.dart';
import 'package:voice_test/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});
  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> with WidgetsBindingObserver {
  String? linkedChildId;
  String? linkedChildName;

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
    setState(() {
      linkedChildId = prefs.getString('linked_child_id');
      if (linkedChildId != null) {
        final liveName = prefs.getString('child_profile_${linkedChildId}_name');
        linkedChildName = liveName ?? prefs.getString('linked_child_name');
      } else {
        linkedChildName = null;
      }
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
                    Text("Welcome 👋", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("Monitor your child", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.settings, size: 28),
                      onPressed: () => Navigator.pushNamed(context, "/settings"),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, size: 28),
                      tooltip: 'Sign Out',
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
            if (linkedChildId != null)
              card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Linked Child", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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
                              Text(linkedChildName ?? "Unknown Child", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("ID: $linkedChildId", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                          child: Text("Connected", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
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
                      Text("Child is safe", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Last updated: Now"),
                    ],
                  ),
                ],
              ),
            ),

            // Safe Card
            card(
              color: Colors.green.shade100,
              child: Row(children: [Text("🟢"), SizedBox(width: 10), Text("No danger detected", style: TextStyle(fontWeight: FontWeight.bold))]),
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
        item("📱", "Link Device", () => Navigator.pushNamed(context, "/parent-scanner").then((_) => _loadLinkedChild())),
        item("🤖", "Camera AI", () => Navigator.pushNamed(context, "/camera-ai").then((_) => _loadLinkedChild())),
        item("🚨", "Alerts", () => Navigator.pushNamed(context, "/alerts").then((_) => _loadLinkedChild())),
        item("📸", "Unknown", () => Navigator.pushNamed(context, "/unknown").then((_) => _loadLinkedChild())),
        item("👥", "Persons", () => Navigator.pushNamed(context, "/persons").then((_) => _loadLinkedChild())),
        item("📅", "History", () => Navigator.pushNamed(context, "/alerts-history").then((_) => _loadLinkedChild())),
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
}
