import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../models/scan_report.dart';
import 'home_screen.dart';

class ScanSeaweedScreen extends StatefulWidget {
  const ScanSeaweedScreen({super.key});
  @override
  State<ScanSeaweedScreen> createState() => _ScanSeaweedScreenState();
}

class _ScanSeaweedScreenState extends State<ScanSeaweedScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _cooldown = false;
  img.Image? _previous;
  final double _motionThreshold = 25; // % of changed pixels to trigger capture

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    _controller!.startImageStream(_processFrame);
    setState(() => _ready = true);

    // Temporary test insert (for DB check only)
    final testReport = ScanReport(
      farmId: 'F001',
      speciesId: 'S001',
      timestamp: DateTime.now().toIso8601String(),
      imageUrl: 'test_path.jpg',
      impurityLevel: 12.5,
      discolorationStatus: 'healthy',
      qualityStatus: 'good',
    );
    await DatabaseHelper.instance.insertReport(testReport);
    debugPrint('✅ Inserted test record on init.');

  }

  /// Convert YUV420 CameraImage (grayscale) to img.Image for comparison
  img.Image _toGray(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final yPlane = image.planes[0].bytes;

    final gray = img.Image(width: w, height: h);
    int i = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final lum = yPlane[i];               // 0..255
        gray.setPixelRgba(x, y, lum, lum, lum, 255); // <-- add alpha
        i++;
      }
    }
    return gray;
  }

  /// Calculate % difference between two grayscale frames
  double _diffPercent(img.Image prev, img.Image curr) {
    int changed = 0;
    int total = prev.width * prev.height;
    const step = 8; // skip pixels for speed

    for (int y = 0; y < prev.height; y += step) {
      for (int x = 0; x < prev.width; x += step) {
        final p1 = prev.getPixel(x, y);
        final p2 = curr.getPixel(x, y);

        // Extract luminance (grayscale intensity)
        final lum1 = img.getLuminance(p1);
        final lum2 = img.getLuminance(p2);

        if ((lum1 - lum2).abs() > 25) changed++;
      }
    }

    final diffPercent = (changed / (total / (step * step))) * 100.0;
    return diffPercent.toDouble();
  }

  void _processFrame(CameraImage frame) async {
    if (_cooldown) return;
    final gray = _toGray(frame);
    if (_previous == null) {
      _previous = gray;
      return;
    }

    double diff = _diffPercent(_previous!, gray);
    _previous = gray;

    if (diff > _motionThreshold) {
      _cooldown = true;
      await _captureAndAnalyze();
      Future.delayed(const Duration(seconds: 3), () => _cooldown = false);
    }
  }

  Future<void> _captureAndAnalyze() async {
    try {
      final shot = await _controller!.takePicture();
      final imagePath = await _saveImage(shot);

      // --- Model calls (replace with your real ones) ---
      final double impurityArea = await _runImpurityModel(imagePath);
      final String health = await _runClassificationModel(imagePath);
      final adjustedImpurity = ((impurityArea / 0.9).clamp(0.0, 100.0)).toDouble();
      final quality = adjustedImpurity > 20 ? 'low' : 'high';

      final report = ScanReport(
        farmId: 'F001',
        speciesId: 'S001',
        timestamp: DateTime.now().toIso8601String(),
        imageUrl: imagePath,
        impurityLevel: adjustedImpurity,
        discolorationStatus: health,
        qualityStatus: quality,
      );
      await DatabaseHelper.instance.insertReport(report);
      debugPrint('✅ Report saved: $imagePath');
    } catch (e) {
      debugPrint('⚠️ Error: $e');
    }
  }

  Future<String> _saveImage(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
    join(dir.path, 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.saveTo(path);
    return path;
  }

  // --- Placeholders for your models ---
  Future<double> _runImpurityModel(String imagePath) async {
    // returns total impurity area (% of frame)
    return 18.5;
  }

  Future<String> _runClassificationModel(String imagePath) async {
    // returns 'healthy' or 'unhealthy'
    return 'healthy';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Seaweed"),
        backgroundColor: Colors.lightGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Home',
            onPressed: () {
              // 🏠 Navigate to your HomeScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ],
      ),
      //TEMPORARY TEST FOR DB
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.list),
        onPressed: () async {
          final db = DatabaseHelper.instance;
          final reports = await db.getAllReports();
          for (var r in reports) {
            debugPrint(
                'ScanID=${r.scanId}, Species=${r.speciesId}, Impurity=${r.impurityLevel}, Health=${r.discolorationStatus}, Status=${r.qualityStatus}');
          }
          debugPrint('Total reports: ${reports.length}');
        },
      ),
      body: Stack(children: [
        CameraPreview(_controller!),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent, width: 3),
            ),
          ),
        ),
      ]),
    );
  }
}
