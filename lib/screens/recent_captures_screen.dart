import 'dart:io';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/scan_report.dart';
import '../screens/scan_seaweed_screen.dart';

class RecentCapturesScreen extends StatefulWidget {
  const RecentCapturesScreen({super.key});

  @override
  State<RecentCapturesScreen> createState() => _RecentCapturesScreenState();
}

class _RecentCapturesScreenState extends State<RecentCapturesScreen> {
  List<ScanReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final db = DatabaseHelper.instance;
    final reports = await db.getRecentReports(limit: 100);
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color aquaBackground = Color(0xFFE0F7F7);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Captures",
            style: TextStyle(color: Colors.black)),
        backgroundColor: aquaBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ScanSeaweedScreen()),
            );
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
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
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
              child: Image.file(
                imageFile,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDetails(BuildContext context, ScanReport report) {
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Captured: ${DateTime.parse(report.timestamp).toLocal()}",
                style:
                const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(report.imageUrl)),
              ),
              const SizedBox(height: 12),
              Text("Impurity: ${report.impurityLevel?.toStringAsFixed(1) ?? '-'}%",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text("Health: ${report.discolorationStatus ?? '-'}",
                  style: const TextStyle(fontSize: 16)),
              Text("Quality: ${report.qualityStatus ?? '-'}",
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
