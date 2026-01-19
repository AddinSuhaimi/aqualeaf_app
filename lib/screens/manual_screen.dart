import 'package:flutter/material.dart';
import 'species_selection_screen.dart';

class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _controller = PageController();
  int _index = 0;

  final List<String> _images = const [
    'assets/manual/manual_1.png',
    'assets/manual/manual_2.png',
    'assets/manual/manual_3.png',
  ];

  final List<String?> _captions = const [
    null, // page 1: no note
    'Seaweed batch thickness must not exceed 1 cm.',
    null, // page 3: no note
  ];

  void _goToSpeciesSelection() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SpeciesSelectionScreen()),
    );
  }

  void _next() {
    if (_index < _images.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _goToSpeciesSelection(); // Done
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _images.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header + Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Seaweed Scanning Guide',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00796B),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _goToSpeciesSelection,
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ),

            // Manual pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final caption = _captions[i];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            Expanded(
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 3.0,
                                child: Image.asset(
                                  _images[i],
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),

                            if (caption != null) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                child: Text(
                                  caption,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_images.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: active ? 14 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF00796B) : Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),
            ),

            // Next / Done
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(isLast ? 'Done' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
