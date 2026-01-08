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

    final statusText = justCaptured
        ? "CAPTURED"
        : (!canCapture ? "WAITING" : "READY");

    final statusColor = justCaptured
        ? Colors.green
        : (!canCapture ? Colors.orangeAccent : darkTeal);

    final q = lastQuality; // 'GOOD' / 'BAD' / null
    final qColor = (q == 'GOOD')
        ? Colors.green
        : (q == 'BAD')
        ? Colors.red
        : Colors.black87;

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

          // Motion capture toggle
          IconButton(
            icon: Icon(
              autoCaptureEnabled ? Icons.motion_photos_on : Icons.motion_photos_off,
              color: Colors.black,
            ),
            tooltip: autoCaptureEnabled
                ? 'Motion capture ON (tap to disable)'
                : 'Motion capture OFF (manual only)',
            onPressed: toggleMotionCapture,
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

                // Centered guide box
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

                // Top-right status (READY / WAITING / CAPTURED)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Opacity(
                    opacity: 0.70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // READY / WAITING / CAPTURED
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 3),

                          // Auto-Capture
                          Text(
                            "Auto: ${autoCaptureEnabled ? 'ON' : 'OFF'}",
                            style: TextStyle(
                              color: autoCaptureEnabled ? Colors.green : Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                  Text("Impurity: ${lastImpurity?.toStringAsFixed(1)}% (BAD if ≥ ${impurityThreshold.toStringAsFixed(1)}%)",
                      style: const TextStyle(color: Colors.black87, fontSize: 16)),
                  Text("Appearance: ${lastHealth ?? '-'}",
                      style: const TextStyle(color: Colors.black87, fontSize: 16)),
                  Text.rich(
                    TextSpan(
                      text: "Quality: ",
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      children: [
                        TextSpan(
                          text: q ?? '-',
                          style: TextStyle(
                            color: qColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
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