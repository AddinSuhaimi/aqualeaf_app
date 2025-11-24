import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../db/database_helper.dart';
import '../models/scan_report.dart';
import 'token_storage.dart';
import '../utils/yolo_preprocessor.dart';

const double MOTION_TRIGGER_MIN = 5;  // must exceed this to consider a pass
const double MOTION_TRIGGER_MAX = 40;  // above this, ignore as “too chaotic”

enum ScanMode { fresh, dried }

abstract class SeaweedScannerBaseState<T extends StatefulWidget> extends State<T> {
  CameraController? _controller;
  bool _isReady = false;
  String? _species;
  bool _modelsLoaded = false;
  double? _lastImpurity = 0.0;
  String? _lastHealth = "-";
  String? _lastQuality = "-";
  Interpreter? _impurityInterpreter;
  Interpreter? _classificationInterpreter;
  double _rawImpurityArea = 0.0;
  bool _torchOn = false;
  final List<Timer> _activeTimers = [];

  // lifecycle guards
  bool _isActive = true;       // false after dispose / stopScanner
  bool _isCapturing = false;   // true while takePicture + analysis is running

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

  ScanMode get scanMode;

  CameraController? get controller => _controller;
  bool get isReady => _isReady;
  bool get modelsLoaded => _modelsLoaded;
  double? get lastImpurity => _lastImpurity;
  String? get lastHealth => _lastHealth;
  String? get lastQuality => _lastQuality;
  bool get torchOn => _torchOn;
  bool get justCaptured => _justCaptured;
  double get latestMotion => _latestMotion;
  bool get canCapture => _canCapture;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModels();
  }

  Future<void> toggleTorch() async {
    if (!_isActive) return;
    if (_controller == null) return;
    _torchOn = !_torchOn;
    await _controller!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    if (!mounted || !_isActive) return;
    setState(() {});
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (!_isActive) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    // Camera settings
    await _controller!.initialize();
    if (!_isActive) return;

    await _controller!.setFlashMode(FlashMode.off);
    await _controller!.setExposurePoint(null);         // center-weighted exposure
    await _controller!.setFocusMode(FocusMode.auto);   // maintain focus
    await _controller!.setExposureOffset(-0.5);

    _controller!.startImageStream(_processFrame);
    if (!mounted || !_isActive) return;
    setState(() => _isReady = true);
  }

  Future<void> _loadModels() async {
    _species = await TokenStorage.getSpecies(); // e.g., 'green', 'brown', 'red'
    if (!_isActive) return;

    try {
      _impurityInterpreter = await Interpreter.fromAsset('assets/models/impurity_best.tflite');

      // For now both modes use the same mapping.
      // TODO: after done dried models, branch on scanMode == ScanMode.dried.
      final modelPath = switch (_species) {
        'green' => 'assets/models/GSW_best.tflite',
        'red' => 'assets/models/RSW_best.tflite',
        'brown' => 'assets/models/BSW_best.tflite',
        _ => 'assets/models/GSW_best.tflite'
      };

      _classificationInterpreter = await Interpreter.fromAsset(modelPath);

      if (!mounted || !_isActive) return;
      setState(() => _modelsLoaded = true);
      debugPrint('Loaded TFLite models for $_species (${scanMode.name})');

      // 🔍 Print model input shapes for debugging
      print('Impurity model input shape: ${_impurityInterpreter!.getInputTensor(0).shape}');
      print('Classification model input shape: ${_classificationInterpreter!.getInputTensor(0).shape}');

      if (mounted && _isActive) {
        ScaffoldMessenger.of(super.context).showSnackBar(
          SnackBar(content: Text('Models loaded for $_species (${scanMode.name})')),
        );
      }
    } catch (e) {
      debugPrint('Failed to load models: $e');
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
    if (!_isActive) return;
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

    if (!_isActive || !mounted) {
      _isProcessing = false;
      return;
    }

    setState(() {
      _latestMotion = avgMotion;
    });

    // Trigger capture only when allowed
    if (_canCapture &&
        avgMotion > MOTION_TRIGGER_MIN &&
        avgMotion < MOTION_TRIGGER_MAX &&
        !_isCapturing &&
        _isActive) {
      await _captureImage();       // first take the photo
      _canCapture = false;         // only lock capture AFTER capture starts
      _startCooldown(avgMotion);
    }

    _isProcessing = false;
  }

  // === Cooldown & re-arm logic ===
  void _startCooldown(double lastMotion) {
    _showCaptureIndicator();
    debugPrint("Cooldown started (0.5s)"); // much shorter

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isActive) return;
      // If the seaweed already left, re-arm immediately
      if (_latestMotion < 5) {
        _canCapture = true;
        debugPrint("Re-armed immediately after capture");
      } else {
        debugPrint("Waiting for scene to clear...");
        _waitUntilClear();
      }
    });
  }

  Future<void> _waitUntilClear() async {
    debugPrint("[Scanner] Waiting for scene to clear...");

    final timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!_isActive) {
        timer.cancel();
        return;
      }
      if (_prevFrame == null) return;
      final motion = motionHistory.isNotEmpty ? motionHistory.last : 0.0;

      if (motion < 5) {
        _canCapture = true;
        debugPrint("[Scanner] Scene cleared → Re-armed");
        timer.cancel();
      }
    });
    _activeTimers.add(timer);

    // safety timeout
    Future.delayed(const Duration(seconds: 6), () {
      if (!_isActive) return;
      if (!_canCapture) {
        _canCapture = true;
        debugPrint("[Scanner] Timeout → Forced re-arm");
      }
    });
  }

  Future<void> handleManualCapture() async {
    if (!_isActive) return;
    if (_isProcessing || !_canCapture || _isCapturing) {
      debugPrint("Manual capture ignored (busy or cooling down)");
      return;
    }

    if (!mounted) return;
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
    if (!_isActive || !mounted) return;
    setState(() => _justCaptured = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isActive || !mounted) return;
      setState(() => _justCaptured = false);
    });
  }

  // === Capture + analyze + store ===
  Future<void> _captureImage() async {
    if (!_isActive) return;
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    _isCapturing = true;
    try {
      final shot = await cam.takePicture();
      if (!_isActive) return;

      final imagePath = await _saveImage(shot);

      final result = await _runImpurityModel(imagePath);
      final impurityPercent = result['impurity'] as double;
      final annotatedPath = result['path'] as String;

      final health = await _runClassificationModel(imagePath);

      final bool isBadClass = scanMode == ScanMode.fresh
          ? health.toLowerCase() == 'unhealthy'
          : health.toLowerCase() == 'unsatisfactory';

      final quality = (impurityPercent > 12 || isBadClass)
          ? 'BAD'
          : 'GOOD';

      // Update HUD
      if (!mounted || !_isActive) return;
      setState(() {
        _lastImpurity = impurityPercent;
        _lastHealth = health;
        _lastQuality = quality;
      });

      final report = ScanReport(
        farmId: 'F001',
        speciesId: 'S001',
        timestamp: DateTime.now().toIso8601String(),
        imageUrl: annotatedPath,
        impurityLevel: impurityPercent,
        discolorationStatus: health,
        qualityStatus: quality,
      );

      await DatabaseHelper.instance.insertReport(report);
      debugPrint('Captured & saved report: $imagePath');
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<String> _saveImage(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
    join(dir.path, 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.saveTo(path);
    return path;
  }

  Future<Map<String, dynamic>> _runImpurityModel(String imagePath) async {
    if (!_modelsLoaded || _impurityInterpreter == null || !_isActive) {
      return {'impurity': 0.0, 'path': imagePath};
    }

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes)!;
      final img.Image original = img.decodeImage(imageBytes)!;

      // === Get model input shape ===
      final inputShape = _impurityInterpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      debugPrint('Impurity inputShape = $inputShape');

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

      // === Convert output safely ===
      // The model returns [[[ [float x 8400] x 5 ]]]
      final List<List<List<double>>> safeOutput = output
          .map<List<List<double>>>(
            (c) => (c as List)
            .map<List<double>>(
              (r) => (r as List)
              .map<double>((v) => (v as num).toDouble())
              .toList(),
        )
            .toList(),
      )
          .toList();

      // === Decode impurity activation ===
      final decoded = decodeImpurityActivation(safeOutput);
      final impurityPercent = decoded['impurity']!;

      // === Heatmap overlay (actual visualization) ===
      final heatmap = img.Image(
        width: original.width,
        height: original.height,
      );

      // Normalize impurity activations for visualization
      final activations = safeOutput[0][4]; // channel 4
      final maxVal = activations.reduce(math.max);
      final minVal = activations.reduce(math.min);
      final scale = (maxVal - minVal).abs() < 1e-9 ? 1.0 : (1 / (maxVal - minVal));

      for (int i = 0; i < activations.length; i++) {
        final norm = ((activations[i] - minVal) * scale).clamp(0.0, 1.0);

        // Map each activation to a grid cell on the 80×80 grid (approx 640/8 stride)
        final stride = 8;
        final x = (i % 80) * stride;
        final y = (i ~/ 80) * stride;

        // Red intensity = impurity activation
        final color = img.ColorRgb8(
          (255 * norm).toInt(),
          (255 * (1 - norm)).toInt(),
          0,
        );

        // Draw a small filled square
        img.fillRect(
          heatmap,
          x1: x,
          y1: y,
          x2: x + stride,
          y2: y + stride,
          color: color,
        );
      }

      // Manually dim the heatmap to simulate transparency
      for (final p in heatmap) {
        final r = (p.r * 0.35).clamp(0, 255).toInt();
        final g = (p.g * 0.35).clamp(0, 255).toInt();
        final b = (p.b * 0.35).clamp(0, 255).toInt();
        p
          ..r = r
          ..g = g
          ..b = b;
      }

      // Blend the softened heatmap onto the original
      img.compositeImage(
        original,
        heatmap,
        dstX: 0,
        dstY: 0,
        blend: img.BlendMode.overlay, // smooth color blend
      );

      // Save heatmap composite
      final heatmapPath = imagePath.replaceAll('.jpg', '_heatmap.jpg');
      final heatmapBytes = img.encodeJpg(original, quality: 90);
      await File(heatmapPath).writeAsBytes(heatmapBytes);


      debugPrint('Impurity=${impurityPercent.toStringAsFixed(2)}% '
          '(mean=${decoded['mean']}, max=${decoded['max']}, '
          'active=${decoded['activeCount']})');

      return {'impurity': impurityPercent, 'path': heatmapPath};
    } catch (e) {
      debugPrint('Impurity model error: $e');
      return {'impurity': 0.0, 'path': imagePath};
    }
  }

  /// Decode YOLOv8 impurity model output [1, 5, 8400]
  /// using activation energy (channel 4 as impurity strength)
  Map<String, double> decodeImpurityActivation(
      List<List<List<double>>> rawOutput) {
    // --- Step 1: Unwrap batch dim if needed ---
    List<List<double>> pred;
    if (rawOutput.length == 1) {
      pred = rawOutput[0]; // shape [5, 8400]
    } else {
      pred = rawOutput.first; // fallback
    }

    final int numChannels = pred.length;
    if (numChannels != 5) {
      throw Exception("Expected 5 channels, got $numChannels");
    }

    final List<double> impurityVals = pred[4]; // channel 4 → impurity logits
    final int numAnchors = impurityVals.length;

    // --- Step 2: Compute stats safely ---
    final double maxVal =
    impurityVals.isNotEmpty ? impurityVals.reduce(math.max) : 0.0;
    final double meanVal = impurityVals.isNotEmpty
        ? impurityVals.reduce((a, b) => a + b) / numAnchors
        : 0.0;

    // --- Step 3: Threshold and count activations ---
    final double thresh = math.max(0.1 * maxVal, 1e-7);
    final int activeCount = impurityVals.where((v) => v > thresh).length;

    // --- Step 4: Activation energy ---
    final double totalEnergy =
    impurityVals.fold<double>(0.0, (a, b) => a + b.abs());
    final double normalizedEnergy =
        totalEnergy / ((maxVal * numAnchors) + 1e-9);

    // --- Step 5: Convert to impurity percentage ---
    const double scaleFactor = 30.0; // tweak later if needed
    final double impurityPercent =
    (normalizedEnergy * scaleFactor * 100.0).clamp(0.0, 100.0);

    // --- Step 6: Debug info ---
    print("Decoding impurity model: $numChannels channels, $numAnchors anchors");
    print("Activation stats → mean=$meanVal, max=$maxVal");
    print("Activated cells: $activeCount / $numAnchors → impurity=$impurityPercent%");

    return {
      'impurity': impurityPercent,
      'mean': meanVal,
      'max': maxVal,
      'activeCount': activeCount.toDouble(),
    };
  }


  Future<String> _runClassificationModel(String imagePath) async {
    if (!_modelsLoaded || _classificationInterpreter == null || !_isActive) return scanMode == ScanMode.fresh ? 'unknown' : 'unknown';

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

          final firstScore = probs[0];
          final secondScore = probs[1];

          debugPrint('Classification probs -> 0=$firstScore, 1=$secondScore');

          if (scanMode == ScanMode.fresh) {
            // [healthy, unhealthy]
            return firstScore > secondScore ? 'healthy' : 'unhealthy';
          } else {
            // dried: [satisfactory, unsatisfactory]
            return firstScore > secondScore ? 'satisfactory' : 'unsatisfactory';
          }
        }
      }

      return scanMode == ScanMode.fresh ? 'unknown' : 'unknown';
    } catch (e) {
      debugPrint('Classification model error: $e');
      return scanMode == ScanMode.fresh ? 'unknown' : 'unknown';
    }
  }

  /// Public helper to stop scanner *before* navigating away.
  Future<void> stopScanner() async {
    _isActive = false;
    _canCapture = false;

    // Wait for any in-progress capture to finish
    while (_isCapturing) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    for (final t in _activeTimers) {
      t.cancel();
    }
    _activeTimers.clear();

    try {
      await _controller?.stopImageStream();
    } catch (_) {}
  }

  @override
  void dispose() {
    _isActive = false;

    for (final t in _activeTimers) {
      t.cancel();
    }
    _activeTimers.clear();

    try {
      _controller?.stopImageStream();
    } catch (_) {}

    _controller?.dispose();
    _impurityInterpreter?.close();
    _classificationInterpreter?.close();
    super.dispose();
  }
}
