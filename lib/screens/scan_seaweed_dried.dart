import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'recent_captures_screen.dart';
import '../services/seaweed_scanner_base.dart';

class ScanSeaweedDried extends StatefulWidget {
  const ScanSeaweedDried({super.key});

  @override
  State<ScanSeaweedDried> createState() => _ScanSeaweedDriedState();
}

class _ScanSeaweedDriedState extends SeaweedScannerBaseState<ScanSeaweedDried> {
  @override
  ScanMode get scanMode => ScanMode.dried;

  @override
  Widget build(BuildContext context) {
    if (!isReady) return const Center(child: CircularProgressIndicator());

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
            onPressed: () async {
              await stopScanner();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.black),
            tooltip: 'Torch',
            onPressed: toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.black),
            tooltip: 'Recent Captures',
            onPressed: () async {
              await stopScanner();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RecentCapturesScreen()),
              );
            },
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
                    width: controller!.value.previewSize!.height,
                    height: controller!.value.previewSize!.width,
                    child:
                    controller != null &&
                        controller!.value.isInitialized &&
                        mounted
                        ? CameraPreview(controller!)
                        : const SizedBox.shrink(),
                  ),
                ),

                // ✅ Centered guide box
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: darkTeal.withValues(alpha: 0.0), width: 2),
                      color: Colors.transparent,
                    ),
                  ),
                ),

                if (justCaptured)
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
                  Text("Motion: ${latestMotion.toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  Text("Impurity: ${lastImpurity?.toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  Text("Appearance: ${lastHealth ?? '-'}",
                      style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  Text("Quality: ${lastQuality ?? '-'}",
                      style: const TextStyle(color: Colors.black87, fontSize: 15)),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: justCaptured
                              ? Colors.green
                              : (!canCapture
                              ? Colors.orangeAccent
                              : darkTeal),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        justCaptured
                            ? "CAPTURED"
                            : (!canCapture ? "WAITING" : "READY"),
                        style: TextStyle(
                          color: justCaptured
                              ? Colors.green
                              : (!canCapture
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
              onPressed: modelsLoaded ? handleManualCapture : null,
            ),
          ),
        ],
      ),
    );
  }
}