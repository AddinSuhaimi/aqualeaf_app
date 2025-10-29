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
  bool _isReady = false;

  // Frame tracking
  img.Image? _prevFrame;
  List<double> motionHistory = [];
  final int windowSize = 5;
  bool _capturing = false;

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
    setState(() => _isReady = true);

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
    debugPrint('Inserted test record on init.');

  }

  // === Convert frame to grayscale ===
  img.Image _toGray(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final yPlane = image.planes[0].bytes;
    final gray = img.Image(width: w, height: h);
    int i = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final lum = yPlane[i];
        gray.setPixelRgba(x, y, lum, lum, lum, 255);
        i++;
      }
    }
    return gray;
  }

  // === Calculate motion difference ===
  double _diffPercent(img.Image prev, img.Image curr) {
    int changed = 0;
    int total = prev.width * prev.height;
    const step = 8;
    for (int y = 0; y < prev.height; y += step) {
      for (int x = 0; x < prev.width; x += step) {
        final p1 = prev.getPixel(x, y);
        final p2 = curr.getPixel(x, y);
        final lum1 = img.getLuminance(p1);
        final lum2 = img.getLuminance(p2);
        if ((lum1 - lum2).abs() > 25) changed++;
      }
    }
    final diffPercent = (changed / (total / (step * step))) * 100.0;
    return diffPercent.toDouble();
  }

  // === Estimate how much of frame is "filled" (coverage %) ===
  double _estimateCoverage(img.Image gray) {
    int filled = 0;
    int total = gray.width * gray.height;
    const step = 8; // skip pixels for speed
    for (int y = 0; y < gray.height; y += step) {
      for (int x = 0; x < gray.width; x += step) {
        final lum = img.getLuminance(gray.getPixel(x, y));
        if (lum < 180) filled++; // darker = likely seaweed
      }
    }
    return (filled / (total / (step * step))) * 100.0; // %
  }

  // === Frame-by-frame processing ===
  void _processFrame(CameraImage frame) async {
    if (_capturing) return;

    final gray = _toGray(frame);
    if (_prevFrame == null) {
      _prevFrame = gray;
      return;
    }

    final diff = _diffPercent(_prevFrame!, gray);
    _prevFrame = gray;

    // Average motion for entry detection
    motionHistory.add(diff);
    if (motionHistory.length > windowSize) motionHistory.removeAt(0);
    final avgMotion = motionHistory.reduce((a, b) => a + b) / motionHistory.length;

    final coverage = _estimateCoverage(gray);

    // Capture when guide box is mostly filled and there is motion
    if (avgMotion > 5 && coverage >= 80 && !_capturing) {
      debugPrint('Coverage=${coverage.toStringAsFixed(1)}%, motion=${avgMotion.toStringAsFixed(1)} → capturing...');
      await _captureImage();
      _startCooldown();
    }
  }

  // === Prevent bursts by cooldown timer ===
  void _startCooldown() {
    _capturing = true;
    debugPrint("Cooldown started (2s)");
    Future.delayed(const Duration(seconds: 2), () {
      _capturing = false;
      debugPrint("Re-armed for next capture");
    });
  }

  // === Capture + analyze + store ===
  Future<void> _captureImage() async {
    try {
      final shot = await _controller!.takePicture();
      final imagePath = await _saveImage(shot);

      final impurityArea = await _runImpurityModel(imagePath);
      final health = await _runClassificationModel(imagePath);
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
      debugPrint('Captured & saved report: $imagePath');
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  Future<String> _saveImage(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
    join(dir.path, 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.saveTo(path);
    return path;
  }

  Future<double> _runImpurityModel(String imagePath) async {
    return 18.7; // placeholder, replace with TFLite result
  }

  Future<String> _runClassificationModel(String imagePath) async {
    return "healthy"; // placeholder, replace with TFLite result
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seaweed Scanner"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Home',
            onPressed: () {
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
      body: Stack(
        children: [
          CameraPreview(_controller!),
          _buildGuideBox(),
        ],
      ),
    );
  }

  Widget _buildGuideBox() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.tealAccent, width: 3),
          color: Colors.transparent,
        ),
      ),
    );
  }
}

