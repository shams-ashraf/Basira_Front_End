import 'package:flutter/material.dart';
import '../../services/face_recognition_service.dart';

class EditPersonScreen extends StatefulWidget {
  final String id;
  final String name;

  const EditPersonScreen({super.key, required this.id, required this.name});

  @override
  _EditPersonScreenState createState() => _EditPersonScreenState();
}

class _EditPersonScreenState extends State<EditPersonScreen> {
  late TextEditingController controller;

  @override
  void initState() {
    controller = TextEditingController(text: widget.name);
    super.initState();
  }

  Future<void> save() async {
    final newName = controller.text.trim();
    if (newName.isEmpty) return;

    try {
      await FaceRecognitionService.instance.updatePerson(int.parse(widget.id), newName);
      await FaceRecognitionService.instance.reloadCache();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Person updated successfully.")),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("UPDATE ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update person: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text("Edit Name"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: save,
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
