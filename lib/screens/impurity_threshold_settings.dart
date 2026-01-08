import 'package:flutter/material.dart';
import '../services/secure_storage.dart';

class ImpurityThresholdSettings extends StatefulWidget {
  const ImpurityThresholdSettings({super.key});

  @override
  State<ImpurityThresholdSettings> createState() =>
      _ImpurityThresholdSettingsState();
}

class _ImpurityThresholdSettingsState
    extends State<ImpurityThresholdSettings> {
  double _value = 2.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await SecureStorage.getImpurityThresholdPercent();
    if (!mounted) return;
    setState(() {
      _value = v.clamp(0.0, 20.0); // clamp safety
      _loading = false;
    });
  }

  Future<void> _save(double v) async {
    await SecureStorage.setImpurityThresholdPercent(v);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Impurity Threshold")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Flag as impure when impurity area ≥ ${_value.toStringAsFixed(1)}%",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _value,
              min: 0.0,
              max: 20.0,
              divisions: 200, // step 0.1
              label: "${_value.toStringAsFixed(1)}%",
              onChanged: (v) {
                setState(() => _value = v);
              },
              onChangeEnd: (v) => _save(v),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tip: Lower = more sensitive (flags impurity easier). Higher = stricter.",
            ),
          ],
        ),
      ),
    );
  }
}
