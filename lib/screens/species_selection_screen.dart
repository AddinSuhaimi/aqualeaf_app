import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import 'home_screen.dart';

class SpeciesSelectionScreen extends StatefulWidget {
  const SpeciesSelectionScreen({super.key});

  @override
  State<SpeciesSelectionScreen> createState() => _SpeciesSelectionScreenState();
}

class _SpeciesSelectionScreenState extends State<SpeciesSelectionScreen> {
  final Map<String, Map<String, dynamic>> seaweedInfo = {
    "Green Seaweed": {
      "color": Colors.green,
      "images": [
        "assets/seaweed/greenseaweed_1.jpg",
        "assets/seaweed/greenseaweed_2.jpg",
        "assets/seaweed/greenseaweed_3.jpg",
      ],
      "description":
      "Green seaweeds (Phylum Chlorophyta) include species such as *Ulva lactuca* and *Enteromorpha prolifera*. They are rich in proteins, vitamins, and minerals.",
      "uses":
      "Commonly used as animal feed, fertilizer, and food supplements in East Asia.",
      "countries": "China, Korea, Japan, Malaysia"
    },
    "Brown Seaweed": {
      "color": Colors.brown,
      "images": [
        "assets/seaweed/brownseaweed_1.jpg",
        "assets/seaweed/brownseaweed_2.jpg",
        "assets/seaweed/brownseaweed_3.jpg",
      ],
      "description":
      "Brown seaweeds (Phylum Ochrophyta) include *Laminaria japonica* and *Undaria pinnatifida*. They are known for their iodine and alginate content.",
      "uses":
      "Used for food (kelp, wakame), alginate extraction, and cosmetics.",
      "countries": "China, South Korea, Japan, Chile"
    },
    "Red Seaweed": {
      "color": Colors.red,
      "images": [
        "assets/seaweed/redseaweed_1.jpg",
        "assets/seaweed/redseaweed_2.jpg",
        "assets/seaweed/redseaweed_3.jpg",
      ],
      "description":
      "Red seaweeds (Phylum Rhodophyta) include *Kappaphycus alvarezii* and *Gracilaria spp.*. They are a primary source of carrageenan and agar.",
      "uses":
      "Used for carrageenan production, agar extraction, and human consumption (nori).",
      "countries": "Philippines, Indonesia, Malaysia, Zanzibar"
    },
  };

  final Set<String> expandedInfo = {};

  Future<void> _selectSpecies(BuildContext context, String species) async {
    await TokenStorage.saveSpecies(species); // store locally
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$species species selected")),
    );

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
          "Select Seaweed Species",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black),
            tooltip: "Back to Home",
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
              "Please select the seaweed species used in your farm:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),

            for (var entry in seaweedInfo.entries)
              _speciesCard(context, entry.key, entry.value),
          ],
        ),
      ),
    );
  }

  Widget _speciesCard(
      BuildContext context, String name, Map<String, dynamic> data) {
    final speciesValue = name.split(' ')[0].toLowerCase();
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    onPressed: () => _selectSpecies(context, speciesValue),
                    child: Text(
                      name,
                      style:
                      const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.info_outline,
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
                ),
              ],
            ),

            // Expanded Info Section
            if (isExpanded) ...[
              const SizedBox(height: 16),
              _localImageCarousel(data["images"]),
              const SizedBox(height: 12),
              Text(
                data["description"],
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 8),
              _infoRow("Common Uses", data["uses"]),
              _infoRow("Common Countries", data["countries"]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _localImageCarousel(List<String> imagePaths) {
    return SizedBox(
      height: 160,
      child: PageView.builder(
        itemCount: imagePaths.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imagePaths[index],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
