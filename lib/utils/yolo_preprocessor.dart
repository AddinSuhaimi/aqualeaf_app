// lib/utils/yolo_preprocessor.dart
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'dart:typed_data';

/// =====================
///  IMAGE PREPROCESSING
/// =====================

/// Resize with letterboxing (keeps aspect ratio + gray padding)
img.Image letterboxResize(img.Image src, int width, int height) {
  final ratio = math.min(width / src.width, height / src.height);
  final newW = (src.width * ratio).toInt();
  final newH = (src.height * ratio).toInt();
  final resized = img.copyResize(src, width: newW, height: newH);

  final boxed = img.Image(width: width, height: height);
  img.fill(boxed, color: img.ColorRgb8(114, 114, 114));

  final dx = ((width - newW) / 2).toInt();
  final dy = ((height - newH) / 2).toInt();
  img.compositeImage(boxed, resized, dstX: dx, dstY: dy);

  return boxed;
}

/// Converts an [img.Image] to a TFLite-compatible [1, height, width, 3] tensor.
/// Normalized to 0–1 for float models.
List<List<List<List<double>>>> preprocessImage(img.Image image, int width, int height) {
  final resized = letterboxResize(image, width, height);
  return [
    List.generate(
      height,
          (y) => List.generate(width, (x) {
        final pixel = resized.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      }),
    ),
  ];
}

List makeNCHWInput(img.Image src, {int size = 224}) {
  final resized = img.copyResize(src, width: size, height: size);

  final r = List.generate(size, (_) => List<double>.filled(size, 0.0));
  final g = List.generate(size, (_) => List<double>.filled(size, 0.0));
  final b = List.generate(size, (_) => List<double>.filled(size, 0.0));

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final p = resized.getPixel(x, y);
      r[y][x] = p.r / 255.0;
      g[y][x] = p.g / 255.0;
      b[y][x] = p.b / 255.0;
    }
  }

  // [1, 3, 224, 224]
  return [[r, g, b]];
}

List<double> softmax2(List<double> logits) {
  final m = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((x) => math.exp(x - m)).toList();
  final sum = exps.fold<double>(0.0, (a, b) => a + b);
  return exps.map((e) => e / (sum == 0 ? 1.0 : sum)).toList();
}

/// =======================
///  YOLOv8 DECODE HELPERS
/// =======================

double sigmoid(double x) => 1 / (1 + math.exp(-x));

class YOLODecoder {
  /// Decode YOLOv8 impurity model output [1,5,8400] with grid stride correction
  static List<Map<String, double>> decodeImpurity(
      dynamic pred, {
        double confThreshold = 1e-8,
        int imageW = 640,
        int imageH = 640,
      }) {
    final boxes = <Map<String, double>>[];

    if (pred is List && pred.length == 1 && pred[0] is List) {
      pred = pred[0];
    }

    if (pred is! List<List<double>>) {
      // print("Unexpected shape: ${pred.runtimeType}");
      return boxes;
    }

    final numChannels = pred.length;
    final numAnchors = pred[0].length;
    // print("Decoding impurity model: $numChannels channels, $numAnchors anchors");

    // stride patterns: 80x80 + 40x40 + 20x20 = 8400
    const strides = [8, 16, 32];
    final gridSizes = [80, 40, 20];
    int offset = 0;

    for (int s = 0; s < strides.length; s++) {
      final gridSize = gridSizes[s];
      final stride = strides[s];
      final numCells = gridSize * gridSize;

      for (int i = 0; i < numCells; i++) {
        final idx = offset + i;
        if (idx >= numAnchors) break;

        final cx = (pred[0][idx]);
        final cy = (pred[1][idx]);
        final w  = (pred[2][idx]);
        final h  = (pred[3][idx]);
        final conf = pred[4][idx];

        if (conf.isNaN || conf < confThreshold) continue;

        // Convert grid-relative to pixel coordinates
        final gridX = i % gridSize;
        final gridY = i ~/ gridSize;

        final px = (gridX + cx / gridSize) * stride;
        final py = (gridY + cy / gridSize) * stride;
        final pw = w * stride;
        final ph = h * stride;

        final x1 = (px - pw / 2).clamp(0.0, imageW.toDouble());
        final y1 = (py - ph / 2).clamp(0.0, imageH.toDouble());
        final x2 = (px + pw / 2).clamp(0.0, imageW.toDouble());
        final y2 = (py + ph / 2).clamp(0.0, imageH.toDouble());

        if ((x2 - x1) < 4 || (y2 - y1) < 4) continue;

        boxes.add({'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'conf': conf});
      }

      offset += numCells;
    }

    // print("Decoded ${boxes.length} impurity boxes");
    return boxes;
  }
}




