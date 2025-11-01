import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../models/scan_report.dart';
import 'home_screen.dart';
import 'dart:io';
import '../services/token_storage.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/yolo_preprocessor.dart';
import 'dart:math' as math;

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
  String? _species;
  bool _modelsLoaded = false;
  double? _lastImpurity = 0.0;
  String? _lastHealth = "-";
  Interpreter? _impurityInterpreter;
  Interpreter? _classificationInterpreter;
  double _rawImpurityArea = 0.0;
  bool _torchOn = false;

  // Frame analysis
  img.Image? _prevFrame;
  List<double> motionHistory = [];
  final int windowSize = 5;

  // Capture + processing control
  bool _isProcessing = false;   // prevents re-entrant frame analysis
  bool _canCapture = true;      // controls capture eligibility
  bool _justCaptured = false;   // visual flash indicator

  // Live stats for HUD
  double _latestMotion = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModels();
  }

  Future<void> _toggleTorch() async {
    if (_controller == null) return;
    _torchOn = !_torchOn;
    await _controller!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    // Camera settings
    await _controller!.initialize();
    await _controller!.setFlashMode(FlashMode.torch);
    await _controller!.setExposurePoint(null);         // center-weighted exposure
    await _controller!.setFocusMode(FocusMode.auto);   // maintain focus
    await _controller!.setExposureOffset(-0.5);

    _controller!.startImageStream(_processFrame);
    setState(() => _isReady = true);
  }

  Future<void> _loadModels() async {
    _species = await TokenStorage.getSpecies(); // e.g., 'green', 'brown', 'red'

    try {
      _impurityInterpreter = await Interpreter.fromAsset('assets/models/impurity_best.tflite');

      final modelPath = switch (_species) {
        'green' => 'assets/models/GSW_best.tflite',
        'red' => 'assets/models/RSW_best.tflite',
        'brown' => 'assets/models/BSW_best.tflite',
        _ => 'assets/models/GSW_best.tflite'
      };

      _classificationInterpreter = await Interpreter.fromAsset(modelPath);

      setState(() => _modelsLoaded = true);
      debugPrint('✅ Loaded TFLite models for $_species');

      // 🔍 Print model input shapes for debugging
      print('Impurity model input shape: ${_impurityInterpreter!.getInputTensor(0).shape}');
      print('Classification model input shape: ${_classificationInterpreter!.getInputTensor(0).shape}');

      if (mounted) {
        ScaffoldMessenger.of(super.context).showSnackBar(
          SnackBar(content: Text('Models loaded for $_species')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load models: $e');
    }
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

    setState(() {
      _latestMotion = avgMotion;
    });

    // Trigger capture only when allowed
    if (_canCapture &&
        avgMotion > MOTION_TRIGGER_MIN &&
        avgMotion < MOTION_TRIGGER_MAX) {
      await _captureImage();       // first take the photo
      _canCapture = false;         // only lock capture AFTER capture starts
      _startCooldown(avgMotion);
    }

    _isProcessing = false;
  }

  // === Cooldown & re-arm logic ===
  void _startCooldown(double lastMotion) {
    _showCaptureIndicator();
    debugPrint("🕒 Cooldown started (0.5s)"); // much shorter

    Future.delayed(const Duration(milliseconds: 500), () {
      // If the seaweed already left, re-arm immediately
      if (_latestMotion < 5) {
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
      final motion = motionHistory.isNotEmpty ? motionHistory.last : 0.0;

      if (motion < 5) {
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

  Future<void> _handleManualCapture() async {
    if (_isProcessing || !_canCapture) {
      debugPrint("⚠️ Manual capture ignored (busy or cooling down)");
      return;
    }

    setState(() {
      _canCapture = false;
    });

    debugPrint("📸 Manual capture triggered");
    await _captureImage();

    // Start cooldown to prevent rapid double captures
    _startCooldown(_latestMotion);
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

      // Update HUD
      setState(() {
        _lastImpurity = adjustedImpurity;
        _lastHealth = health;
      });

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
    if (!_modelsLoaded || _impurityInterpreter == null) return 0.0;

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes)!;

      // === Get model input shape ===
      final inputShape = _impurityInterpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];

      debugPrint('📏 Impurity inputShape = $inputShape');

      // === Preprocess image (NHWC layout) ===
      final input = preprocessImage(image, inputWidth, inputHeight);

      // === Prepare output tensor ===
      final outputShape = _impurityInterpreter!.getOutputTensor(0).shape;
      final outputFlat = List<double>.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      );
      final output = outputFlat.reshape(outputShape);

      // === Run inference ===
      _impurityInterpreter!.run(input, output);

      // === Normalize dynamic list ===
      final safeOutput = (output as List)
          .map((e) => (e as List)
          .map((x) => (x as List).map((v) => (v as num).toDouble()).toList())
          .toList())
          .toList();

      // === Decode detections ===
      final detections = decodeYoloOutputFlexible(
        safeOutput,
        inputWidth,
        inputHeight,
        objThresh: 0.30,
        confThresh: 0.40,
        nmsIoU: 0.45,
      );

      // === Compute impurity area (pixels) ===
      double totalArea = 0.0;
      for (final box in detections) {
        final w = (box[2] - box[0]);
        final h = (box[3] - box[1]);
        totalArea += w * h;
      }

      final guideBoxArea = 0.8 * (inputWidth * inputHeight);
      final impurityPercent = ((totalArea / guideBoxArea) * 100.0).clamp(0.0, 100.0);

      // === Update debug HUD ===
      setState(() => _rawImpurityArea = totalArea);

      debugPrint(
        '🧮 YOLO decoded boxes=${detections.length}, '
            'totalArea=${totalArea.toStringAsFixed(1)} px², '
            'guideBoxArea=${guideBoxArea.toStringAsFixed(1)} px² → '
            'impurity=${impurityPercent.toStringAsFixed(2)}%',
      );

      return impurityPercent;
    } catch (e) {
      debugPrint('⚠️ Impurity model error: $e');
      return 0.0;
    }
  }

  Future<String> _runClassificationModel(String imagePath) async {
    if (!_modelsLoaded || _classificationInterpreter == null) return 'unknown';

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes)!;

      // === Get input shape ===
      final inputShape = _classificationInterpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];

      // === Preprocess the image (reuse from utils) ===
      final input = preprocessImage(image, inputWidth, inputHeight);

      // === Prepare output tensor ===
      final outputShape = _classificationInterpreter!.getOutputTensor(0).shape;
      final output = List.filled(outputShape.reduce((a, b) => a * b), 0.0)
          .reshape(outputShape);

      // === Run inference ===
      _classificationInterpreter!.run(input, output);

      // === Interpret results ===
      if (output.isNotEmpty) {
        final result = output[0];
        if (result is List && result.length >= 2) {
          // Apply softmax
          final expScores = result.map((x) => math.exp(x)).toList();
          final sumExp = expScores.fold<double>(0.0, (a, b) => a + b);
          final probs = expScores.map((x) => x / (sumExp == 0 ? 1.0 : sumExp)).toList();

          final healthyScore = probs[0];
          final unhealthyScore = probs[1];

          debugPrint('🌿 Classification probs -> healthy=$healthyScore, unhealthy=$unhealthyScore');
          return healthyScore > unhealthyScore ? 'healthy' : 'unhealthy';
        }
      }

      return 'unknown';
    } catch (e) {
      debugPrint('⚠️ Classification model error: $e');
      return 'unknown';
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _impurityInterpreter?.close();
    _classificationInterpreter?.close();
    super.dispose();
  }


  // =======================================================
  // ==================== UI BUILDERS ======================
  // =======================================================

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const Center(child: CircularProgressIndicator());

    const Color aquaBackground = Color(0xFFE0F7F7);
    const Color darkTeal = Color(0xFF00796B);
    const Color deepGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: deepGreen,
      appBar: AppBar(
        backgroundColor: deepGreen,
        elevation: 0,
        title: const Text(
          "Seaweed Scanner",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
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
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.black),
            tooltip: 'Torch',
            onPressed: _toggleTorch,
          ),
        ],
      ),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // === CAMERA PREVIEW ===
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize!.height,
                    height: _controller!.value.previewSize!.width,
                    child: CameraPreview(_controller!),
                  ),
                ),

                // ✅ Centered guide box
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: darkTeal.withValues(alpha: 0.8), width: 2),
                      color: Colors.transparent,
                    ),
                  ),
                ),

                if (_justCaptured)
                  Container(color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
          ),

          // === HUD BELOW CAMERA ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Motion: ${_latestMotion.toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  Text("Impurity: ${_lastImpurity?.toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  Text("Raw Impurity Area: ${_rawImpurityArea.toStringAsFixed(1)}",
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  Text("Health: ${_lastHealth ?? '-'}",
                      style: const TextStyle(color: Colors.black87, fontSize: 14)),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _justCaptured
                              ? Colors.green
                              : (!_canCapture
                              ? Colors.orangeAccent
                              : darkTeal),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _justCaptured
                            ? "CAPTURED"
                            : (!_canCapture ? "WAITING" : "READY"),
                        style: TextStyle(
                          color: _justCaptured
                              ? Colors.green
                              : (!_canCapture
                              ? Colors.orangeAccent
                              : darkTeal),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // === MANUAL CAPTURE BUTTON ===
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: FloatingActionButton(
              backgroundColor: aquaBackground,
              child: const Icon(Icons.camera_alt, size: 32, color: Colors.black),
              onPressed: _modelsLoaded ? _handleManualCapture : null,
            ),
          ),
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
            // Existing stats
            Text("Motion: ${_latestMotion.toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 14)),

            // 👇 Add these two new lines right below Coverage
            Text("Impurity: ${_lastImpurity?.toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text("Raw Impurity Area: ${_rawImpurityArea.toStringAsFixed(1)}",
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text("Health: ${_lastHealth ?? '-'}",
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


