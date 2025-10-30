import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../models/scan_report.dart';
import 'home_screen.dart'; // adjust path if needed

const double MOTION_TRIGGER_MIN = 5;  // must exceed this to consider a pass
const double MOTION_TRIGGER_MAX = 40;  // above this, ignore as “too chaotic”

class ScanSeaweedScreen extends StatefulWidget {
  const ScanSeaweedScreen({super.key});

  @override
  State<ScanSeaweedScreen> createState() => _ScanSeaweedScreenState();
}

class _ScanSeaweedScreenState extends State<ScanSeaweedScreen> {
  CameraController? _controller;
  bool _isReady = false;

  // Frame analysis
  img.Image? _prevFrame;
  List<double> motionHistory = [];
  final int windowSize = 5;

  // Capture + processing control
  bool _isProcessing = false;   // prevents re-entrant frame analysis
  bool _canCapture = true;      // controls capture eligibility
  bool _justCaptured = false;   // visual flash indicator

  // Live stats for HUD
  double _latestCoverage = 0.0;
  double _latestMotion = 0.0;

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

    // Disable flash to prevent battery drain
    await _controller!.setFlashMode(FlashMode.off);

    _controller!.startImageStream(_processFrame);
    setState(() => _isReady = true);
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

  // === Guide box region ===
  Rect guideBoxRect(img.Image frame) {
    final w = frame.width;
    final h = frame.height;
    final boxW = (w * 0.8).toInt();
    final boxH = (h * 0.8).toInt();
    final startX = ((w - boxW) / 2).toInt();
    final startY = ((h - boxH) / 2).toInt();
    return Rect.fromLTWH(startX.toDouble(), startY.toDouble(), boxW.toDouble(), boxH.toDouble());
  }

  double _averageLuminance(img.Image frame, Rect box) {
    int total = 0, count = 0;
    for (int y = box.top.toInt(); y < box.bottom.toInt(); y += 8) {
      for (int x = box.left.toInt(); x < box.right.toInt(); x += 8) {
        total += img.getLuminance(frame.getPixel(x, y)).toInt();
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  // === Frame difference percentage (motion) ===
  double _diffPercent(img.Image prev, img.Image curr) {
    final r = guideBoxRect(prev);
    final avgPrev = _averageLuminance(prev, r);
    final avgCurr = _averageLuminance(curr, r);
    int changed = 0, total = 0;
    const step = 8;

    for (int y = r.top.toInt(); y < r.bottom.toInt(); y += step) {
      for (int x = r.left.toInt(); x < r.right.toInt(); x += step) {
        final lum1 = img.getLuminance(prev.getPixel(x, y)) - avgPrev;
        final lum2 = img.getLuminance(curr.getPixel(x, y)) - avgCurr;
        if ((lum1 - lum2).abs() > 25) changed++;
        total++;
      }
    }
    return (changed / total) * 100.0;
  }

  // === Estimate coverage of dark regions (adaptive & sensitive) ===
  double _estimateCoverage(img.Image gray) {
    final r = guideBoxRect(gray);
    List<double> luminances = [];
    const step = 8;

    for (int y = r.top.toInt(); y < r.bottom.toInt(); y += step) {
      for (int x = r.left.toInt(); x < r.right.toInt(); x += step) {
        luminances.add(img.getLuminance(gray.getPixel(x, y)).toDouble());
      }
    }

    if (luminances.isEmpty) return 0.0;
    final avg = luminances.reduce((a, b) => a + b) / luminances.length;

    // More sensitive (0.95)
    int filled = 0;
    for (final lum in luminances) {
      if (lum < avg * 0.95) filled++;
    }

    return (filled / luminances.length) * 100.0;
  }

  // === Frame-by-frame processing ===
  void _processFrame(CameraImage frame) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final gray = _toGray(frame);
    if (_prevFrame == null) {
      _prevFrame = gray;
      _isProcessing = false;
      return;
    }

    final diff = _diffPercent(_prevFrame!, gray);
    _prevFrame = gray;

    motionHistory.add(diff);
    if (motionHistory.length > windowSize) motionHistory.removeAt(0);
    final avgMotion = motionHistory.reduce((a, b) => a + b) / motionHistory.length;

    final coverage = _estimateCoverage(gray);

    setState(() {
      _latestCoverage = coverage;
      _latestMotion = avgMotion;
    });

    // Trigger capture only when allowed
    if (_canCapture &&
        avgMotion > MOTION_TRIGGER_MIN &&
        avgMotion < MOTION_TRIGGER_MAX &&
        coverage >= 50) {
      debugPrint(
          'Coverage=${coverage.toStringAsFixed(1)}%, Motion=${avgMotion.toStringAsFixed(1)}% → Capture');
      await _captureImage();       // first take the photo
      _canCapture = false;         // only lock capture AFTER capture starts
      _startCooldown(coverage, avgMotion);
    }

    _isProcessing = false;
  }

  // === Cooldown & re-arm logic ===
  void _startCooldown(double lastCoverage, double lastMotion) {
    _showCaptureIndicator();
    debugPrint("🕒 Cooldown started (0.5s)"); // much shorter

    Future.delayed(const Duration(milliseconds: 500), () {
      // If the seaweed already left, re-arm immediately
      if (_latestCoverage < 50 && _latestMotion < 5) {
        _canCapture = true;
        debugPrint("🔄 Re-armed immediately after capture");
      } else {
        debugPrint("⚙️ Waiting for scene to clear...");
        _waitUntilClear();
      }
    });
  }

  Future<void> _waitUntilClear() async {
    debugPrint("[Scanner] Waiting for scene to clear...");

    Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (_prevFrame == null) return;
      final coverage = _estimateCoverage(_prevFrame!);
      final motion = motionHistory.isNotEmpty ? motionHistory.last : 0.0;

      if (coverage < 50 && motion < 5) {
        _canCapture = true;
        debugPrint("[Scanner] ✅ Scene cleared → Re-armed");
        timer.cancel();
      }
    });

    // safety timeout
    Future.delayed(const Duration(seconds: 6), () {
      if (!_canCapture) {
        _canCapture = true;
        debugPrint("[Scanner] ⚠️ Timeout → Forced re-arm");
      }
    });
  }

  // === Visual indicator that a capture occurred ===
  void _showCaptureIndicator() {
    setState(() => _justCaptured = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _justCaptured = false);
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
      debugPrint('📸 Captured & saved report: $imagePath');
    } catch (e) {
      debugPrint('⚠️ Capture error: $e');
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
    return 18.7; // placeholder for TFLite result
  }

  Future<String> _runClassificationModel(String imagePath) async {
    return "healthy"; // placeholder for TFLite result
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
      body: Stack(
        children: [
          CameraPreview(_controller!),
          _buildGuideBox(),
          _buildHUD(),
          if (_justCaptured)
            Container(color: Colors.white.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildGuideBox() {
    return Center(
      child: Container(
        width: 280, // enlarged visible guide box
        height: 280,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.tealAccent, width: 3),
          color: Colors.transparent,
        ),
      ),
    );
  }

  // === HUD Overlay ===
  Widget _buildHUD() {
    String status;
    Color statusColor;

    if (_justCaptured) {
      status = "CAPTURED";
      statusColor = Colors.greenAccent;
    } else if (!_canCapture) {
      status = "WAITING";
      statusColor = Colors.orangeAccent;
    } else {
      status = "READY";
      statusColor = Colors.tealAccent;
    }

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Motion: ${_latestMotion.toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text("Coverage: ${_latestCoverage.toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(status,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



