import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import 'login_screen.dart';
import 'species_selection_screen.dart';
import 'type_selection_screen.dart';
import 'scan_seaweed_fresh.dart';
import 'scan_seaweed_dried.dart';
import 'view_database_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Map<String, dynamic>?>? _future;
  String? _species;
  String? _type;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchFarmDetails();
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    final s = await SecureStorage.getSpecies();
    final t = await SecureStorage.getType();
    setState(() {
      _species = s;
      _type = t;
    });
  }

  String formatSpecies(String? s) {
    switch (s) {
      case 'green': return 'Green Seaweed';
      case 'red': return 'Red Seaweed';
      case 'brown': return 'Brown Seaweed';
      default: return 'Not selected';
    }
  }

  String formatType(String? t) {
    switch (t) {
      case 'fresh': return 'Fresh Seaweed';
      case 'dried': return 'Dried Seaweed';
      default: return 'Not selected';
    }
  }

  Future<void> _refresh() async {
    final f = ApiService.fetchFarmDetails();
    setState(() => _future = f);
  }

  void _logout() async {
    await SecureStorage.clearToken();
    await SecureStorage.clearSpecies();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7F7), // light aqua like the mock
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE0F7F7),
        title: const Text(
          'Home',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // === Row: Species + Type buttons ===
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5), // blue
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SpeciesSelectionScreen()),
                      );
                    },
                    child: const Text("Set Seaweed Species"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A), // purple
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const TypeSelectionScreen()),
                      );
                    },
                    child: const Text("Set Seaweed Type"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // === "View Recent Reports" full-width button ===
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B), // teal
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViewDatabaseScreen()),
                  );
                },
                child: const Text("View Recent Reports"),
              ),
            ),

            const SizedBox(height: 24),

            FutureBuilder<Map<String, dynamic>?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _cardContainer(
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _cardContainer(
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('Error loading data'),
                    ),
                  );
                }

                final data = snapshot.data;

                if (data == null) {
                  return _cardContainer(
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No data'),
                    ),
                  );
                }

                if (data['offline'] == true) {
                  return _cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Farm Account Details (Offline Mode)",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        _tile(
                          icon: Icons.person_outline,
                          title: "Manager: ${data['managerName'] ?? '-'}",
                          subtitle: "Email: ${data['managerEmail'] ?? '-'}",
                        ),
                        const Divider(),
                        _tile(
                          icon: Icons.place_outlined,
                          title: "Farm: ${data['farmName'] ?? '-'}",
                          subtitle: "Location: ${data['farmLocation'] ?? '-'}",
                        ),
                        const Divider(),
                        _tile(
                          icon: Icons.settings_outlined,
                          title: 'Selected Seaweed Species:',
                          subtitle: formatSpecies(_species),
                        ),
                        const Divider(),
                        _tile(
                          icon: Icons.category_outlined,
                          title: 'Selected Seaweed Type:',
                          subtitle: formatType(_type),
                        ),
                      ],
                    ),
                  );
                }

                if (data['__unauthorized'] == true) {
                  // Token invalid/expired -> log out
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _logout();
                  });
                  return const SizedBox.shrink();
                }

                final managerName = data['managerName'] ?? '-';
                final managerEmail = data['managerEmail'] ?? '-';
                final farmName = data['farmName'] ?? '-';
                final farmLocation = data['farmLocation'] ?? '-';
                final uploadStatus = data['uploadStatus'] ?? 'Unknown';
                final lastUpdated = data['lastUpdated'] ?? '';

                return _cardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Farm Account Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _tile(
                        icon: Icons.person_outline,
                        title: 'Manager: $managerName',
                        subtitle: 'Email: $managerEmail',
                      ),
                      const Divider(),
                      _tile(
                        icon: Icons.place_outlined,
                        title: 'Farm: $farmName',
                        subtitle: 'Location: $farmLocation',
                      ),
                      const Divider(),
                      _tile(
                        icon: Icons.settings_outlined,
                        title: 'Selected Seaweed Species:',
                        subtitle: formatSpecies(_species),
                      ),
                      const Divider(),
                      _tile(
                        icon: Icons.category_outlined,
                        title: 'Selected Seaweed Type:',
                        subtitle: formatType(_type),
                      ),
                      const Divider(),
                      _tile(
                        icon: Icons.sync_outlined,
                        title: 'Results Upload Status',
                        subtitle:
                        '$uploadStatus\n${lastUpdated.isNotEmpty ? "Last updated: $lastUpdated" : ""}',
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            // Bottom CTA button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32), // green
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final type = await SecureStorage.getType();
                  if (!context.mounted) return;
                  if (type == "dried") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanSeaweedDried()),
                    );
                  } else {
                    // Default: fresh
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanSeaweedFresh()),
                    );
                  }
                },
                child: const Text(
                  'Scan Seaweed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: child,
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}
