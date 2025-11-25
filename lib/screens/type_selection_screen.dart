import 'package:flutter/material.dart';
import '../services/secure_storage.dart';
import 'home_screen.dart';

class TypeSelectionScreen extends StatefulWidget {
  const TypeSelectionScreen({super.key});

  @override
  State<TypeSelectionScreen> createState() => _TypeSelectionScreenState();
}

class _TypeSelectionScreenState extends State<TypeSelectionScreen> {
  final Map<String, Map<String, dynamic>> typeInfo = {
    "Fresh Seaweed": {
      "color": Colors.blue,
      "description":
      "Fresh seaweed refers to newly harvested seaweed that still retains moisture. This type is used for quality scanning such as impurity detection and health analysis.",
    },
    "Dried Seaweed": {
      "color": Colors.orange,
      "description":
      "Dried seaweed has undergone drying to reduce moisture content. This type is scanned for appearance quality such as impurity detection and shape consistency.",
    }
  };

  final Set<String> expandedInfo = {};

  Future<void> _selectType(BuildContext context, String type) async {
    await SecureStorage.saveType(type.toLowerCase()); // fresh / dried

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$type selected")),
    );

    // Navigate to home screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE0F7F7),
        elevation: 0,
        title: const Text(
          "Select Seaweed Type",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const Text(
              "Choose whether you are scanning fresh or dried seaweed:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),

            for (var entry in typeInfo.entries)
              _typeCard(context, entry.key, entry.value),
          ],
        ),
      ),
    );
  }

  Widget _typeCard(BuildContext context, String name, Map<String, dynamic> data) {
    final typeValue = name.split(' ')[0].toLowerCase();
    final isExpanded = expandedInfo.contains(name);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: data["color"],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _selectType(context, typeValue),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.info_outline,
                    color: Colors.grey[700],
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        expandedInfo.remove(name);
                      } else {
                        expandedInfo.add(name);
                      }
                    });
                  },
                )
              ],
            ),

            if (isExpanded) ...[
              const SizedBox(height: 16),
              const SizedBox(height: 12),
              Text(
                data["description"],
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imageCarousel(List<String> images) {
    return SizedBox(
      height: 160,
      child: PageView.builder(
        itemCount: images.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                images[index],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          );
        },
      ),
    );
  }
}
