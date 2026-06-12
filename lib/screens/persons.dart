import 'package:flutter/material.dart';
import '../services/face_recognition_service.dart';
import '../services/backend_service.dart';
import '../app_header.dart';
import 'edit_person.dart';
import 'person_details.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({super.key});

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<Map<String, dynamic>> data = [];
  bool loading = true;
  bool deleting = false;

  @override
  void initState() {
    super.initState();
    FaceRecognitionService.instance.init().catchError((e) {
      debugPrint("FACE INIT ERROR: $e");
    });
    load();
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
            const SnackBar(
                content: Text("Offline mode: Showing local persons")),
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
      await FaceRecognitionService.instance
          .deletePerson(id); // Delete locally first
      await FaceRecognitionService.instance
          .reloadCache(); // Reload cache immediately
      try {
        await BackendService.instance.deletePerson(id);
      } catch (e) {
        debugPrint("BACKEND DELETE ERROR: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Deleted locally. Backend sync failed.")),
          );
        }
      }

      if (mounted) {
        setState(() {
          data.removeWhere((p) => p["id"] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Person deleted successfully")),
        );
      }
    } catch (e) {
      debugPrint("DELETE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Delete failed")),
        );
      }
    }

    deleting = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: "Persons 👥"),
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
                child: const Center(
                  child: Text(
                    "➕ Add Person",
                    style: TextStyle(
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
                    ? const Center(child: Text("No persons added yet"))
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
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      // Action buttons
                                      GestureDetector(
                                        onTap: () => delete(p["id"]),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFDDDD),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text("🗑 Delete"),
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
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text("✏️ Edit"),
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
