import 'package:flutter/material.dart';
import '../../services/backend_service.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final logs = await BackendService.instance.getSystemLogs(limit: 150);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
      case 'CRITICAL':
        return Colors.redAccent;
      case 'WARNING':
        return Colors.orangeAccent;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FB),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('System Logs'),
        backgroundColor: const Color(0xFF2C3E6B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadLogs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _logs.isEmpty
                  ? const Center(child: Text('No system logs yet.'))
                  : RefreshIndicator(
                      onRefresh: _loadLogs,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final log = _logs[index];
                          final level = (log['level'] ?? 'INFO').toString();
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _levelColor(level).withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _levelColor(level).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        level,
                                        style: TextStyle(
                                          color: _levelColor(level),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${log['module'] ?? 'System'} • ${log['action'] ?? 'Event'}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (log['message'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if ((log['details'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    log['details'].toString(),
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  (log['timestamp'] ?? '').toString(),
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
