import 'dart:io';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/scan_report_fresh.dart';
import '../models/scan_report_dried.dart';

class ViewDatabaseScreen extends StatefulWidget {
  const ViewDatabaseScreen({super.key});

  @override
  State<ViewDatabaseScreen> createState() => _ViewDatabaseScreenState();
}

class _ViewDatabaseScreenState extends State<ViewDatabaseScreen> {
  bool loading = true;
  List<ScanReportFresh> freshReports = [];
  List<ScanReportDried> driedReports = [];

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final db = DatabaseHelper.instance;

    final fresh = await db.getRecentFreshReports();
    final dried = await db.getRecentDriedReports();

    setState(() {
      freshReports = fresh;
      driedReports = dried;
      loading = false;
    });
  }

  String capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  // Small badge widget for sync status
  Widget _syncBadge(int synced) {
    final isSynced = synced == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSynced ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSynced ? 'Synced' : 'Pending',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSynced ? Colors.green[800] : Colors.orange[800],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Recent Reports"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionTitle("Fresh Scan Reports (${freshReports.length})"),
          ...freshReports.map(_freshTile).toList(),
          const SizedBox(height: 24),

          _sectionTitle("Dried Scan Reports (${driedReports.length})"),
          ...driedReports.map(_driedTile).toList(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// FRESH ROW DISPLAY
  Widget _freshTile(ScanReportFresh r) {
    return Card(
      child: ListTile(
        leading: _imagePreview(r.imageUrl),
        title: Text("Fresh • ${r.qualityStatus}"),
        subtitle: Text(
          "Impurity: ${r.impurityStatus.toStringAsFixed(1)}%\n"
              "Health: ${capitalize(r.healthStatus)}\n"
              "SpeciesID: ${r.speciesId}  FarmID: ${r.farmId}\n"
              "${r.timestamp}",
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _syncBadge(r.synced),
        onTap: () => _openDetails(context, r),
      ),
    );
  }

  /// DRIED ROW DISPLAY
  Widget _driedTile(ScanReportDried r) {
    return Card(
      child: ListTile(
        leading: _imagePreview(r.imageUrl),
        title: Text("Dried • ${r.qualityStatus}"),
        subtitle: Text(
          "Impurity: ${r.impurityStatus.toStringAsFixed(1)}%\n"
              "Appearance: ${capitalize(r.appearance)}\n"
              "SpeciesID: ${r.speciesId}  FarmID: ${r.farmId}\n"
              "${r.timestamp}",
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _syncBadge(r.synced),
        onTap: () => _openDetails(context, r),
      ),
    );
  }

  Widget _imagePreview(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Icon(Icons.broken_image, size: 48);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        file,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
      ),
    );
  }

  /// POPUP DETAIL VIEWER
  void _openDetails(BuildContext context, dynamic report) {
    final bool isSynced = report.synced == 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Timestamp: ${report.timestamp}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),

                Text(
                  "Sync status: ${isSynced ? "Synced to cloud" : "Pending upload"}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSynced ? Colors.green[700] : Colors.orange[700],
                  ),
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(report.imageUrl)),
                ),

                const SizedBox(height: 16),

                Text("Farm ID: ${report.farmId}"),
                Text("Species ID: ${report.speciesId}"),
                Text("Impurity: ${report.impurityStatus.toStringAsFixed(1)}%"),
                Text("Quality: ${report.qualityStatus}"),

                if (report is ScanReportFresh)
                  Text("Health: ${report.healthStatus}"),

                if (report is ScanReportDried)
                  Text("Appearance: ${report.appearance}"),
              ],
            ),
          ),
        );
      },
    );
  }
}
