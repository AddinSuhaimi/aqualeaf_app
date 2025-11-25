import 'dart:io';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';

import '../services/secure_storage.dart';
import '../screens/scan_seaweed_fresh.dart';
import '../screens/scan_seaweed_dried.dart';

class RecentCapturesScreen extends StatefulWidget {
  const RecentCapturesScreen({super.key});

  @override
  State<RecentCapturesScreen> createState() => _RecentCapturesScreenState();
}

class _RecentCapturesScreenState extends State<RecentCapturesScreen> {
  List<dynamic> _reports = [];     // can hold fresh OR dried
  String _type = 'fresh';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final db = DatabaseHelper.instance;
    final type = await SecureStorage.getType() ?? "fresh";

    List<dynamic> reports;
    if (type == 'dried') {
      reports = await db.getRecentDriedReports(limit: 100);
    } else {
      reports = await db.getRecentFreshReports(limit: 100);
    }

    setState(() {
      _type = type;
      _reports = reports;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color aquaBackground = Color(0xFFE0F7F7);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Captures", style: TextStyle(color: Colors.black)),
        backgroundColor: aquaBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_type == 'dried') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ScanSeaweedDried()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ScanSeaweedFresh()),
              );
            }
          },
        ),
      ),
      backgroundColor: aquaBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? const Center(child: Text("No captures found."))
          : GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          final imageFile = File(report.imageUrl);
          if (!imageFile.existsSync()) {
            return const Icon(Icons.broken_image);
          }
          return GestureDetector(
            onTap: () => _openDetails(context, report),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(imageFile, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  void _openDetails(BuildContext context, dynamic report) {
    final bool isFresh = _type == "fresh";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Captured: ${DateTime.parse(report.timestamp).toLocal()}",
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(report.imageUrl)),
              ),

              const SizedBox(height: 12),

              // COMMON
              Text(
                "Impurity: ${report.impurityStatus.toStringAsFixed(1)}%",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),

              // DIFFERENT FOR FRESH VS DRIED
              Text(
                isFresh
                    ? "Health: ${report.healthStatus}"
                    : "Appearance: ${report.appearance}",
                style: const TextStyle(fontSize: 16),
              ),

              Text(
                "Quality: ${report.qualityStatus}",
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

