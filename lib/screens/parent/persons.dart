import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../app_header.dart';
import '../../l10n.dart';
import '../../services/backend_service.dart';
import '../../services/face_recognition_service.dart';
import 'edit_person.dart';
import 'person_details.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> data = [];
  bool loading = true;
  bool deleting = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FaceRecognitionService.instance.init().catchError((e) {
      debugPrint("FACE INIT ERROR: $e");
    });
    load();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !loading) {
        load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      data = await BackendService.instance.getAllPersons();
    } catch (e) {
      debugPrint("LOAD ERROR: $e");
      try {
        data = await FaceRecognitionService.instance.getAllPersons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.tr('persons_offline'))),
          );
        }
      } catch (localE) {
        debugPrint("LOCAL LOAD ERROR: $localE");
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> delete(int id) async {
    if (deleting) return;
    deleting = true;

    try {
      await FaceRecognitionService.instance.deletePerson(id);
      await FaceRecognitionService.instance.reloadCache();
      try {
        await BackendService.instance.deletePerson(id);
      } catch (e) {
        debugPrint("BACKEND DELETE ERROR: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.tr('persons_delete_local'))),
          );
        }
      }

      if (mounted) {
        setState(() {
          data.removeWhere((p) => p["id"] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.tr('persons_deleted'))),
        );
      }
    } catch (e) {
      debugPrint("DELETE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.tr('persons_delete_failed'))),
        );
      }
    }

    deleting = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: L10n.tr('persons_title')),
      backgroundColor: const Color(0xFFEEF4FB),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, "/add").then((_) => load());
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8DEF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    L10n.tr('persons_add'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? Center(child: Text(L10n.tr('persons_none')))
                    : ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (_, i) {
                          final p = data[i];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PersonDetailsScreen(
                                    id: p["id"],
                                    name: p["name"],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 5),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => delete(p["id"]),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFDDDD),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(L10n.tr('persons_delete')),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditPersonScreen(
                                                id: p["id"].toString(),
                                                name: p["name"],
                                              ),
                                            ),
                                          ).then((_) => load());
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEEEEE),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(L10n.tr('persons_edit')),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    p["name"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
