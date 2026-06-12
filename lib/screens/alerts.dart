import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_header.dart';
import '../services/backend_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> alerts = [];
  String? childId;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      childId = prefs.getString('linked_child_id') ?? prefs.getString('child_id');
    });
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final result = await BackendService.instance.getAlerts(childId: childId);
    if (mounted) {
      setState(() {
        alerts = result;
        loading = false;
      });
    }
  }

  Color _colorFor(String type) {
    switch (type.toLowerCase()) {
      case 'sos':
        return Colors.red.shade100;
      case 'unknown person':
        return Colors.orange.shade100;
      default:
        return Colors.blueGrey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: "Alerts"),
      backgroundColor: const Color(0xFFEEF4FB),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: alerts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Icon(Icons.notifications_none, size: 72, color: Colors.grey)),
                        SizedBox(height: 12),
                        Center(child: Text("No alerts yet")),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: alerts.length,
                      itemBuilder: (_, index) {
                        final alert = alerts[index];
                        final type = alert['type']?.toString() ?? 'Alert';
                        final message = alert['message']?.toString() ?? '';
                        final timestamp = alert['timestamp']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _colorFor(type),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.black87),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(message),
                                    if (timestamp.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(timestamp, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
