// lib/utils/yolo_preprocessor.dart
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// === IMAGE PREPROCESSING ===
/// Converts an [img.Image] to a TFLite-compatible [1, height, width, 3] tensor.
/// Values are normalized to 0–1 for float models.
/// If your model is quantized (uint8), change the division to keep 0–255 values.
List<List<List<List<double>>>> preprocessImage(img.Image image, int width, int height) {
  // Resize to model input size
  final resized = img.copyResize(image, width: width, height: height);

  // Channels-last layout (NHWC)
  return [
    List.generate(
      height,
          (y) => List.generate(
        width,
            (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        },
      ),
    ),
  ];
}

/// === SIGMOID HELPER ===
double sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

/// === NON-MAX SUPPRESSION ===
List<List<double>> nonMaxSuppression(List<List<double>> boxes, {double iouThreshold = 0.45}) {
  boxes.sort((a, b) => b[4].compareTo(a[4]));
  final picked = <List<double>>[];
  while (boxes.isNotEmpty) {
    final current = boxes.removeAt(0);
    picked.add(current);
    boxes.removeWhere((box) {
      final x1 = math.max(current[0], box[0]);
      final y1 = math.max(current[1], box[1]);
      final x2 = math.min(current[2], box[2]);
      final y2 = math.min(current[3], box[3]);
      final inter = math.max(0, x2 - x1) * math.max(0, y2 - y1);
      final areaA = (current[2] - current[0]) * (current[3] - current[1]);
      final areaB = (box[2] - box[0]) * (box[3] - box[1]);
      final union = areaA + areaB - inter;
      return union <= 0 ? false : (inter / union) > iouThreshold;
    });
  }
  return picked;
}

/// === YOLO OUTPUT DECODER ===
/// Works with ONNX→TF→TFLite models (no exp() on w/h, pixel-safe)
/// Expects each detection row: [cx, cy, w, h, obj_conf, cls0, cls1, ...]
List<List<double>> decodeYoloOutputFlexible(
    dynamic output,
    int W,
    int H, {
      double objThresh = 0.30,
      double confThresh = 0.40,
      double nmsIoU = 0.45,
    }) {
  final boxes = <List<double>>[];
  final rows = (output as List)[0] as List;

  for (final row in rows) {
    final det = (row as List).map((v) => (v as num).toDouble()).toList();
    if (det.length < 5) continue;

    // Confidence processing
    double obj = det[4];
    if (obj < 0.0 || obj > 1.0) obj = sigmoid(obj);
    if (obj < objThresh) continue;

    double clsConf = 1.0;
    if (det.length > 5) {
      final clsScores = det.sublist(5);
      double maxCls = clsScores.reduce(math.max);
      if (maxCls < 0.0 || maxCls > 1.0) maxCls = sigmoid(maxCls);
      clsConf = maxCls;
    }
    final conf = obj * clsConf;
    if (conf < confThresh) continue;

    // Box conversion (normalized or pixel)
    double cx = det[0], cy = det[1], w = det[2], h = det[3];
    if (cx <= 1.5 && cy <= 1.5) { cx *= W; cy *= H; }
    if (w  <= 1.5 && h  <= 1.5) { w  *= W; h  *= H; }

    double x1 = cx - w / 2.0;
    double y1 = cy - h / 2.0;
    double x2 = cx + w / 2.0;
    double y2 = cy + h / 2.0;

    // Clip and sanity filter
    x1 = x1.clamp(0.0, W.toDouble());
    y1 = y1.clamp(0.0, H.toDouble());
    x2 = x2.clamp(0.0, W.toDouble());
    y2 = y2.clamp(0.0, H.toDouble());

    final bw = x2 - x1;
    final bh = y2 - y1;
    if (bw < 4 || bh < 4) continue;
    if (bw > W * 1.2 || bh > H * 1.2) continue;

    boxes.add([x1, y1, x2, y2, conf]);
  }

  return nonMaxSuppression(boxes, iouThreshold: nmsIoU);
}
